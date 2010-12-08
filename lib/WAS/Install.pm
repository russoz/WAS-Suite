package WAS::Install;

use Carp;
use Moose;
use common::sense;

use version; our $VERSION = qv('0.0.5');

use WAS::App;
use WAS::Server;

use File::Spec::Functions;
use File::Path qw(make_path);
use File::Copy;

use DateTime;
use DateTime::TimeZone;
use Net::SSH::Perl;
use Net::SFTP;

use Data::Dumper;

use autodie;

##############################################################################

has 'application' => ( is => 'ro', isa => 'WAS::App',    required => 1 );
has 'server'      => ( is => 'ro', isa => 'WAS::Server', required => 1 );

# installation-related attributes
has 'really_do' => ( is => 'ro', isa => 'Bool', default => 0 );

# sudo attributes
has '_use_sudo' => ( is => 'rw', isa => 'Bool', predicate => 'has_sudo', );
has '_sudo'     => ( is => 'rw', isa => 'Str',  default   => 'sudo', );
has '_sudo_user' => ( is => 'rw', isa => 'Str', predicate => 'has_sudo_user', );

# local file preparation/execution attributes
has 'local_base_dir' => ( is => 'rw', isa => 'Str', required => 1, );
has 'local_work_dir' => ( is => 'rw', isa => 'Str', );
has 'local_appear'   => ( is => 'rw', isa => 'Str', );
has 'local_script'   => ( is => 'rw', isa => 'Str', );

# remote-installation -related attributes
has 'rem_host' => ( is => 'rw', isa => 'Str', predicate => 'is_remote', );
has 'rem_user' =>
  ( is => 'rw', isa => 'Str', default => getpwuid($<) || undef, );
has 'rem_pass' => ( is => 'rw', isa => 'Str', predicate => 'has_password', );
has 'rem_work_dir' => ( is => 'rw', isa => 'Str', );
has 'rem_appear'   => ( is => 'rw', isa => 'Str', );
has 'rem_script'   => ( is => 'rw', isa => 'Str', );

has 'rem_tmp_dir' =>
  ( is => 'ro', isa => 'Str', default => catfile( rootdir(), 'tmp' ), );

has 'rem_ssh_args' =>
  ( is => 'rw', isa => 'HashRef', predicate => 'has_ssh_args', );

# time-keeping attributes
has 'timezone' => (
    is      => 'ro',
    isa     => 'DateTime::TimeZone',
    default => sub {
        use DateTime::TimeZone;
        return DateTime::TimeZone->new( name => 'local' );
    },
);

has 'timestamp' => (
    is      => 'ro',
    isa     => 'DateTime',
    default => sub {
        use DateTime;
        return DateTime->now;
    },
);

# output-related attributes
has 'output' =>
  ( is => 'rw', isa => 'FileHandle', default => sub { *STDERR{IO} }, );
has 'cmd_output' =>
  ( is => 'rw', isa => 'FileHandle', default => sub { *STDERR{IO} }, );

##############################################################################

my @_indent = ( '===', '      ', '      \=>', '            ', );

sub _msg {
    my $self   = shift;
    my $level  = shift;
    my $handle = $self->output;
    local $, = ' ';
    print $handle $_indent[ $level - 1 ], @_;
    print $handle "\n";
}

sub _timestamp {
    my $self = shift;
    my $now  = shift;

    # masturbacao semantica - mas eh legal
    return sub { my $t = shift; return $t->ymd('.') . '-' . $t->hms('.') }
      ->(
        $now eq 'now'
        ? DateTime->now->set_time_zone( $self->timezone )
        : $self->timestamp->set_time_zone( $self->timezone )
      );
}

sub _gen_script {
    my $self = shift;
    my $spec = shift;

    $spec->{timestamp} = $self->_timestamp('now');
    $spec->{tz}        = $self->timezone->name;

    # making sure the flag is correctly set in here
    if ( $self->really_do ) {
        $spec->{really_do} = 1;
        $self->_msg( 3,
            'DRY-RUN: the generated script will not actually update anything' );
    }
    else {
        $spec->{really_do} = 0;
    }

    #print STDERR Dumper($spec);
    my $rawdata = join '', (<DATA>);
    my $data = eval "qq{$rawdata}";

    open( my $file, '>', $spec->{script} );

    #print STDERR $data;
    print $file $data;
    close $file;

    return;
}

sub _remloc {
    my ( $self, $d ) = @_;
    return $self->rem_user . '@' . $self->rem_host . ':' . $d;
}

sub prepare_files {
    my ( $self, $earfile ) = @_;

    $self->_msg( 1, 'Preparing files' );
    my $timestamp = $self->_timestamp();
    $self->_msg( 2, 'Timestamp:', $timestamp );
    my $scriptfile = 'update-ear-.py';

    $self->local_work_dir(
        catfile( $self->local_base_dir, 'work', $timestamp ) );
    $self->_msg( 2, 'Local work directory:', $self->local_work_dir );
    $self->local_script( catfile( $self->local_work_dir, $scriptfile ) );
    $self->local_appear( catfile( $self->local_work_dir, $earfile ) );

    make_path( $self->local_work_dir );

    # Generate script
    $self->_msg( 2, 'Generating script:', $self->local_script );
    $self->_gen_script( { script => $self->local_script, } );

    # Copy EAR file
    $self->_msg( 2, 'Copying EAR file.:', $self->local_appear );
    copy( $earfile, $self->local_appear )
      or croak qq{Failed to copy '$earfile' to '$self->local_appear' ($!)};
    $self->_msg( 1, 'prepare_file() completed' );

    # prepare remote installation
    if ( $self->is_remote ) {
        $self->rem_work_dir(
            catfile(
                $self->rem_tmp_dir,
                'was-deploy-'
                  . $self->was_app_name . '-'
                  . $timestamp . '-'
                  . $$
            )
        );
        $self->rem_script( catfile( $self->rem_work_dir, $scriptfile ) );
        $self->rem_appear( catfile( $self->rem_work_dir, $earfile ) );

        $self->_prepare_remote_install;
    }
}

sub _prepare_remote_install {
    my $self = shift;

    $self->_msg( 1, 'Preparing remote installation' );

    $self->_msg(
        2,
        'Opening connection to:',
        $self->rem_user . '@' . $self->rem_host
    );
    my $sftp = Net::SFTP->new(
        $self->rem_host,
        user => $self->rem_user,
        $self->has_password ? ( password => $self->rem_pass )     : (),
        $self->has_ssh_args ? ( ssh_args => $self->rem_ssh_args ) : (),
    ) || croak qq{Cannot open a SFTP connection!};

    my $attr = Net::SFTP::Attributes->new();
    $attr->perm('0755');

    $self->_msg( 3, 'Creating remote directory:', $self->rem_work_dir );
    $sftp->do_mkdir( $self->rem_work_dir, $attr );

    $self->_msg( 3, 'Copying script..:', $self->rem_script );
    $sftp->put( $self->local_script, $self->rem_script )
      || croak q{Cannot copy file "}
      . $self->local_script
      . q{" to }
      . $self->_remloc( $self->rem_work_dir );

    $self->_msg( 3, 'Copying EAR file:', $self->rem_appear );
    $sftp->put( $self->local_appear, $self->rem_appear )
      || croak q{Cannot copy file "}
      . $self->local_appear
      . q{" to }
      . $self->_remloc( $self->rem_work_dir );
    $self->_msg( 1, 'prepare_remote_install() completed' );
}

sub do_install {
    my $self = shift;
    if ( $self->is_remote ) {
        $self->_do_remote_install;
    }
    else {
        $self->_do_local_install;
    }
}

sub _make_cmd {
    my $self = shift;

    my $wsadmin = catfile( $self->was_profile_path, 'bin', $self->cmd_wsadmin );

    #my $cmd  = 'echo ';
    my $cmd = '';
    my $sudo =
      $self->sudo . ( $self->has_sudo_user ? ' -u ' . $self->sudo_user : '' );
    $cmd .= $sudo if $self->has_sudo();
    $cmd .=
        $self->cmd_wsadmin_prefix() . ' ' 
      . $wsadmin
      . ' -lang jython -f '
      . ( $self->is_remote ? $self->rem_script : $self->local_script ) . ' '
      . $self->cmd_wsadmin_suffix();
    $cmd .= ' '
      . $self->was_app_name . ' '
      . ( $self->is_remote ? $self->rem_appear : $self->local_appear );
    return $cmd;
}

sub _do_local_install {
    my $self = shift;

    $self->_msg( 1, 'Doing local install' );

    my $cmd = $self->_make_cmd;
    $self->_msg( 2, 'cmd: ', $cmd );
    $self->_msg( 3, 'Dispatching installation command' );
    $self->_msg( 1, '_do_local_install() completed' );
}

sub _do_remote_install {
    my $self = shift;

    $self->_msg( 1, 'Doing remote install' );

    my $cmd = $self->_make_cmd;
    $self->_msg( 2, 'cmd: ', $cmd );

    $self->_msg( 2, 'Opening SSH connection with host:', $self->rem_host );
    my $ssh = Net::SSH::Perl->new(
        $self->rem_host,
        protocol => 2,
        use_pty  => 1,
        $self->has_ssh_args ? @{ $self->rem_ssh_args } : (),
    ) || croak q{Cannot open a SSH connection!};

    $self->_msg( 3, 'Logging in...' );
    $ssh->login( $self->rem_user, $self->has_password ? $self->rem_pass : () );

    #print $self->output 'DEBUG: ' . $cmd . "\n";
    $self->_msg( 3, 'Dispatching installation command' );
    $self->_msg( 4, 'DRY-RUN: Not actually installing!' );
    my ( $out, $err, $exit ) = $ssh->cmd($cmd);

    my $handle = $self->cmd_output;
    foreach my $eline ( split $/, $err ) {
        print $handle 'ERR: ' . $eline . "\n";
    }
    foreach my $oline ( split $/, $out ) {
        print $handle '> ' . $oline . "\n";
    }
    croak 'Failed to run remote command (' . $exit . '): $!' if $exit;

    $self->_msg( 1, '_do_remote_install() completed' );
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;    # Magic true value required at end of module

__END__

=head1 NAME

WAS::Install - Application installation for WebSphere


=head1 SYNOPSIS

    use WAS::Install;

    my $app = Was::Install->new( ... );
    my $rem_script = $app->prepare_files( 'myapp.ear' );
    my $exit = $app->do_install( $rem_script );

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=over

=item prepare_files( EARFILE)

Given an EARFILE, this method will prepare a wsadmin jython script to 
install it, and copy both the script and the EARFILE to a specific directory.

=item do_install()

Executes the installation script.

=back

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
WAS::App::Install requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-was-remote-install@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Alexei Znamensky  C<< <russoz@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2010, Alexei Znamensky C<< <russoz@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

