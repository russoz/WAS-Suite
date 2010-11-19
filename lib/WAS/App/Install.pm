package WAS::App::Install;

use Carp;
use Moose;
use common::sense;

use File::Spec::Functions;
use File::Path qw(make_path);
use File::Copy;

use DateTime;
use DateTime::TimeZone;
use Net::SSH::Perl;
use Net::SFTP;

use Data::Dumper;

use autodie;
use version; our $VERSION = qv('0.0.5');

##############################################################################

# installation-related attributes
has 'sudo'      => ( is => 'rw', isa => 'Str',  default   => 'sudo', );
has 'sudo_user' => ( is => 'rw', isa => 'Str',  predicate => 'has_sudo_user', );
has 'use_sudo'  => ( is => 'rw', isa => 'Bool', predicate => 'has_sudo', );

# local file preparation/execution attributes
has 'local_base_dir' => ( is => 'rw', isa => 'Str', required => 1, );
has 'local_work_dir' => ( is => 'rw', isa => 'Str', );
has 'appear'         => ( is => 'rw', isa => 'Str', );
has 'script'         => ( is => 'rw', isa => 'Str', );

# websphere-related attributes
has 'was_profile_path' => ( is => 'rw', isa => 'Str', required => 1, );
has 'was_app_name'     => ( is => 'rw', isa => 'Str', required => 1, );
has 'cmd_wsadmin_prefix' => ( is => 'rw', isa => 'Str', );
has 'cmd_wsadmin' => ( is => 'rw', isa => 'Str', default => 'wsadmin.sh', );
has 'cmd_wsadmin_suffix' => ( is => 'rw', isa => 'Str', );

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
    print $handle $_indent[$level], @_;
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
    my $spec = shift;

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
    my $scriptfile = 'script-' . $timestamp . '.py';

    $self->local_work_dir(
        catfile( $self->local_base_dir, 'work', $timestamp ) );
    $self->_msg( 2, 'Local work directory:', $self->local_work_dir );
    $self->script( catfile( $self->local_work_dir, $scriptfile ) );
    $self->appear( catfile( $self->local_work_dir, $earfile ) );

    make_path( $self->local_work_dir );

    # Generate script
    $self->_msg( 2, 'Generating script:', $self->script );
    _gen_script(
        {
            script => $self->script,
            tz     => $self->timezone->name,
        }
    );

    # Copy EAR file
    $self->_msg( 2, 'Copying EAR file.:', $self->appear );
    copy( $earfile, $self->appear )
      or croak qq{Failed to copy '$earfile' to '$self->appear' ($!)};
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
    $sftp->put( $self->script, $self->rem_script )
      || croak q{Cannot copy file "}
      . $self->script
      . q{" to }
      . $self->_remloc( $self->rem_work_dir );

    $self->_msg( 3, 'Copying EAR file:', $self->rem_appear );
    $sftp->put( $self->appear, $self->rem_appear )
      || croak q{Cannot copy file "}
      . $self->appear
      . q{" to }
      . $self->_remloc( $self->rem_work_dir );
    $self->_msg( 1, 'prepare_remote_install() completed' );
}

sub do_remote_install {
    my $self = shift;

    $self->_msg( 1, 'Doing remote install' );
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
      . $self->rem_script . ' '
      . $self->cmd_wsadmin_suffix();
    $cmd .= ' ' . $self->was_app_name . ' ' . $self->rem_appear;
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
    my ( $out, $err, $exit ) = $ssh->cmd($cmd);

    my $handle = $self->cmd_output;
    foreach my $eline ( split $/, $err ) {
        print $handle 'ERR: ' . $eline . "\n";
    }
    foreach my $oline ( split $/, $out ) {
        print $handle '> ' . $oline . "\n";
    }
    croak 'Failed to run remote command (' . $exit . '): $!' if $exit;

    $self->_msg( 1, 'do_remote_install() completed' );
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;    # Magic true value required at end of module

__DATA__
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

appname=sys.argv[0]
appear =sys.argv[1]

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

