package WAS::Remote::App;

use Carp;
use Moose;
use common::sense;

use File::Spec;
use File::Path qw(make_path);
use File::Copy;
use Try::Tiny;

use DateTime;
use DateTime::TimeZone;
use Net::SSH::Perl;
use Net::SFTP;

use Data::Dumper;

use autodie;
use version; our $VERSION = qv('0.0.4');

has 'local_base_dir' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has 'rem_host' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has 'rem_user' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has 'rem_pass' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_password',
);

has 'rem_profile_path' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has 'rem_app_name' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has 'rem_tmp_dir' => (
    is      => 'rw',
    isa     => 'Str',
    default => File::Spec->catfile( File::Spec->rootdir(), 'tmp' ),
);

has 'rem_sudo_user' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_sudo',
);

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

has 'cmd_wsadmin' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'wsadmin.sh',
);

has 'cmd_wsadmin_prefix' => (
    is  => 'rw',
    isa => 'Str',
);

has 'cmd_wsadmin_suffix' => (
    is  => 'rw',
    isa => 'Str',
);

has 'local_work_dir' => (
    is  => 'rw',
    isa => 'Str',
);

has 'appear' => (
    is  => 'rw',
    isa => 'Str',
);

has 'script' => (
    is  => 'rw',
    isa => 'Str',
);

has 'rem_work_dir' => (
    is  => 'rw',
    isa => 'Str',
);

has 'rem_appear' => (
    is  => 'rw',
    isa => 'Str',
);

has 'rem_script' => (
    is  => 'rw',
    isa => 'Str',
);

sub _timestamp {
    my $self = shift;
    return $self->timestamp->set_time_zone( $self->timezone )->ymd('.');
}

sub _gen_script {
    my $spec = shift;

    #print Dumper($spec);
    my $tzname = $spec->{tz}->name;

    open( my $file, '>', $spec->{script} );
    print $file <<"EOF";
# update-ear.py
#
# Alexei Znamensky
# russoz AT cpan.org
#

import sys, java
from java.util import Date,TimeZone
from java.text import SimpleDateFormat

tzspec="$tzname"

tz = TimeZone.getTimeZone(tzspec)
df = SimpleDateFormat("yyyy.MM.dd HH:mm:ss.SSS z")
df.setTimeZone(tz)

def log(msg):
    print >> sys.stderr, "=== ["+df.format(Date())+"]", msg

appname="$spec->{appname}"
appear ="$spec->{appear}"

options = [ "-update", "-appname", appname, "-update.ignore.new", "-verbose" ]

try:
    log("Installing Application from "+appear)
    AdminApp.install( appear, options )
    log("Installation completed")

    log("Saving configuration")
    AdminConfig.save()

except:
    print '************ EXCEPTION:'
    print sys.exc_info()
    print 'Modifications not saved'
    exit(1)

EOF
    close $file;

    return;
}

sub _remloc {
    my ( $self, $d ) = @_;
    return $self->rem_user . '@' . $self->rem_host . ':' . $d;
}

sub prepare_files {
    my ( $self, $earfile ) = @_;

    my $timestamp  = $self->_timestamp();
    my $scriptfile = 'script-' . $timestamp . '.py';

    $self->local_work_dir(
        File::Spec->catfile( $self->local_base_dir, 'work', $timestamp ) );
    $self->script( File::Spec->catfile( $self->local_work_dir, $scriptfile ) );
    $self->appear( File::Spec->catfile( $self->local_work_dir, $earfile ) );

    make_path( $self->local_work_dir );

    $self->rem_work_dir(
        File::Spec->catfile(
            $self->rem_tmp_dir, 'was-remote-app-' . $timestamp . '-' . $$
        )
    );
    $self->rem_script(
        File::Spec->catfile( $self->rem_work_dir, $scriptfile ) );
    $self->rem_appear( File::Spec->catfile( $self->rem_work_dir, $earfile ) );

    # Generate script
    _gen_script(
        {
            script  => $self->script,
            tz      => $self->timezone,
            appname => $self->rem_app_name,
            appear  => $self->rem_appear,
        }
    );

    # Copy EAR file
    copy( $earfile, $self->appear )
      or croak qq{Failed to copy '$earfile' to '$self->appear' ($!)};
}

sub prepare_remote_install {
    my $self = shift;

    my $sftp = Net::SFTP->new(
        $self->rem_host,

        #debug    => 1,
        ssh_args => { compression => 0 },
        user     => $self->rem_user,
        $self->has_password ? ( password => $self->rem_pass ) : (),
    ) || croak qq{Cannot open a SFTP connection!};

    my $attr = Net::SFTP::Attributes->new();
    $attr->perm('0755');

    $sftp->do_mkdir( $self->rem_work_dir, $attr );

    $sftp->put( $self->script, $self->rem_script )
      || croak q{Cannot copy file "}
      . $self->script
      . q{" to }
      . $self->_remloc( $self->rem_work_dir );

    $sftp->put( $self->appear, $self->rem_appear )
      || croak q{Cannot copy file "}
      . $self->appear
      . q{" to }
      . $self->_remloc( $self->rem_work_dir );
}

sub do_remote_install {
    my $self = shift;

    my $wsadmin =
      File::Spec->catfile( $self->rem_profile_path, 'bin', $self->cmd_wsadmin );
    my $cmd  = '/bin/echo ';
    my $sudo = 'sudo -u ' . $self->rem_sudo_user() . ' ';
    $cmd .= $sudo if $self->has_sudo();
    $cmd .=
        $self->cmd_wsadmin_prefix() . ' ' 
      . $wsadmin
      . ' -lang jython '
      . $self->rem_script . ' '
      . $self->cmd_wsadmin_suffix();

    my $ssh = Net::SSH::Perl->new(
        $self->rem_host,
        debug       => 2,
        use_pty     => 0,
        compression => 0
    ) || croak q{Cannot open a SSH connection!};

    $ssh->login( $self->rem_user,
        $self->has_password ? $self->rem_pass : undef );

    print 'DEBUG: ' . $cmd . "\n";

    #my ( $out, $err, $exit ) = $ssh->cmd( $cmd );
    my ( $out, $err, $exit ) = $ssh->cmd('ls -l');
    croak 'Failed to run remote command (' . $exit . '): $!' if $exit;

    print STDERR "=== ERR\n";
    while ( my $errline = <$err> ) {
        print STDERR $errline;
    }
    print STDERR "=======.\n";
    print STDERR "=== OUT\n";
    while ( my $outline = <$out> ) {
        print STDERR $outline;
    }
    print STDERR "=======.\n";

    return $exit;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;    # Magic true value required at end of module
__END__

=head1 NAME

WAS::Remote::App - Remote application control for WebSphere


=head1 SYNOPSIS

    use WAS::Remote::App;

    my $app = Was::Remote::App->new( ... );
    my $rem_script = $app->prepare_remote_install( 'myapp.ear' );
    my $exit = $app->do_remote_install( $rem_script );

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

=item prepare_remote_install()

This method will copy the files prepared by the C<< prepare_files() >> method
to a temporary location in the remote server.  This currently works only with
UNIX systems with SSH daemons.

=item do_remote_install()

Executes the installation script in the remote server.

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
  
WAS::Remote::App requires no configuration files or environment variables.


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
