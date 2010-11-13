package WAS::Remote::App;

use Carp;
use Moose;
use File::Spec;
use File::Path qw(make_path);
use File::Copy;
use Try::Tiny;

use autodie;
use version; our $VERSION = qv('0.0.3');

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

has 'rem_profile_path' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has 'rem_was_server' => (
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
    default => 'tmp',
);

has 'rem_sudo_user' => (
    is  => 'rw',
    isa => 'Str',
);

has 'timezone' => (
    is      => 'ro',
    isa     => 'Str',
    default => sub {
        use DateTime::TimeZone;
        return DateTime::TimeZone->( name => 'local' );
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

has 'wsadmin_cmd' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'wsadmin.sh',
);

has 'cmd_prefix' => (
    is  => 'rw',
    isa => 'Str',
);

has 'cmd_suffix' => (
    is  => 'rw',
    isa => 'Str',
);

sub _timestamp {
    my $self = shift;
    return $self->timestamp->set_time_zone( $self->timezone )->ymd('.');
}

sub _gen_script {
    my $spec = shift;

    my $file = undef;
    try {
        open( $file, '>', $spec->{script} );
        print $file <<"EOF";
# update-ear.py
#
# Alexei Znamensky
# russoz AT cpan.org
#

import sys, java
from java.util import Date,TimeZone
from java.text import SimpleDateFormat

tzspec="$spec->{tz}"

if len(sys.argv) != 2:
    print >> sys.stderr, 'update-ear.py: <enterprise-app> <ear-file>'
    sys.exit(1)

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
    }
    finally {
        close $file;
    }
    return;
}

sub _remloc {
    my ( $self, $d ) = @_;
    return $self->rem_user . '@' . $self->rem_host . ':' . $d;
}

sub prepare_remote_install {
    my ( $self, $earfile ) = shift;

    my $timestamp = $self->_timestamp();

    my $scriptfile = 'script-' . $timestamp . '.py';
    my $local_work_dir =
      File::Spec->catfile( $self->local_base_dir, 'work', $timestamp );

    make_path($local_work_dir)
      || die 'Cannot create directory: ' . $local_work_dir;

    my $script = File::Spec->catfile( $local_work_dir, $scriptfile );
    my $appear = File::Spec->catfile( $local_work_dir, $earfile );

    _gen_script(
        {
            script  => $script,
            tz      => $self->timezone,
            appname => $self->rem_app_name,

            # the jython script must use relative name
            appear => $earfile,
        }
    );

    my $sftp = Net::SFTP->( $self->rem_host, user => $self->rem_user );

    #my $attrs = Net::SFTP::Attributes->new();
    #$attrs->perms( 0770 );

    my $rem_work_dir =
      File::Spec->catfile( File::Spec->rootdir(), $self->rem_tmp_dir,
        'was-remote-app-' . $$ . '-' . $timestamp );

    $sftp->do_mkdir($rem_work_dir);

    $sftp->put( $script, File::Spec->catfile( $rem_work_dir, $scriptfile ) )
      || die q{Cannot copy file "}
      . $scriptfile
      . q{" to }
      . $self->_remloc($rem_work_dir);

    $sftp->put( $appear, File::Spec->catfile( $rem_work_dir, $earfile ) )
      || die q{Cannot copy file "} 
      . $earfile 
      . q{" to }
      . $self->_remloc($rem_work_dir);

    return;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;    # Magic true value required at end of module
__END__

=head1 NAME

WAS::Remote::App - Remote application control for WebSphere


=head1 SYNOPSIS

    use WAS::Remote::App;

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

=item prepare_remote_install( EARFILE )

This method will prepare installation scripts to deploy EARFILE into the
instance-defined WAS instance and application. This currently works only
with UNIX systems with SSH daemons.

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
