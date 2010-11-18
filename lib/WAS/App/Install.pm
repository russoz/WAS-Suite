package WAS::App::Install;

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
use version; our $VERSION = qv('0.0.5');

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

has 'rem_sudo' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'sudo',
);

has 'rem_sudo_user' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_sudo_user',
);

has 'rem_use_sudo' => (
    is        => 'rw',
    isa       => 'Bool',
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

has 'output' => (
    is      => 'rw',
    isa     => 'FileHandle',
    default => sub {
        return *STDERR{IO};
    },
);

has 'cmd_output' => (
    is      => 'rw',
    isa     => 'FileHandle',
    default => sub {
        return *STDERR{IO};
    },
);

sub _msg {
    my $self   = shift;
    my $level  = shift;
    my $handle = $self->output;
    local $, = ' ';
    print $handle '===' x $level, @_;
    print $handle "\n";
}

sub _timestamp {
    my $self = shift;
    return $self->timestamp->set_time_zone( $self->timezone )->ymd('.');
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
        File::Spec->catfile( $self->local_base_dir, 'work', $timestamp ) );
    $self->_msg( 2, 'Local work directory:', $self->local_work_dir );
    $self->script( File::Spec->catfile( $self->local_work_dir, $scriptfile ) );
    $self->appear( File::Spec->catfile( $self->local_work_dir, $earfile ) );

    make_path( $self->local_work_dir );

    $self->rem_work_dir(
        File::Spec->catfile(
            $self->rem_tmp_dir,
            'was-deploy-' . $self->rem_app_name . '-' . $timestamp . '-' . $$
        )
    );
    $self->rem_script(
        File::Spec->catfile( $self->rem_work_dir, $scriptfile ) );
    $self->rem_appear( File::Spec->catfile( $self->rem_work_dir, $earfile ) );

    # Generate script
    $self->_msg( 2, 'Generating script:', $self->script );
    _gen_script(
        {
            script  => $self->script,
            tz      => $self->timezone->name,
            appname => $self->rem_app_name,
            appear  => $self->rem_appear,
        }
    );

    # Copy EAR file
    $self->_msg( 2, 'Copying EAR file.:', $self->appear );
    copy( $earfile, $self->appear )
      or croak qq{Failed to copy '$earfile' to '$self->appear' ($!)};
    $self->_msg( 1, 'prepare_file() completed' );
}

sub prepare_remote_install {
    my $self = shift;

    $self->_msg( 1, 'Preparing remote installation' );

    $self->_msg(
        2,
        'Opening connection to:',
        $self->rem_user . '@' . $self->rem_host
    );
    my $sftp = Net::SFTP->new(
        $self->rem_host,

        #debug    => 1,
        ssh_args => { compression => 0 },
        user     => $self->rem_user,
        $self->has_password ? ( password => $self->rem_pass ) : (),
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
    my $wsadmin =
      File::Spec->catfile( $self->rem_profile_path, 'bin', $self->cmd_wsadmin );

    #my $cmd  = 'echo ';
    my $cmd  = '';
    my $sudo = $self->rem_sudo
      . ( $self->has_sudo_user ? ' -u ' . $self->rem_sudo_user : '' );
    $cmd .= $sudo if $self->has_sudo();
    $cmd .=
        $self->cmd_wsadmin_prefix() . ' ' 
      . $wsadmin
      . ' -lang jython -f '
      . $self->rem_script . ' '
      . $self->cmd_wsadmin_suffix();
    $self->_msg( 2, 'cmd: ', $cmd );

    $self->_msg( 2, 'Opening SSH connection with host:', $self->rem_host );
    my $ssh = Net::SSH::Perl->new(
        $self->rem_host,
        protocol => 2,
        use_pty  => 1,
    ) || croak q{Cannot open a SSH connection!};

    $self->_msg( 3, 'Logging in...' );
    $ssh->login( $self->rem_user,
        $self->has_password ? $self->rem_pass() : undef );

    #print $self->output 'DEBUG: ' . $cmd . "\n";

    $self->_msg( 3, 'Dispatching installation command' );
    my ( $out, $err, $exit ) = $ssh->cmd($cmd);

    #my ( $out, $err, $exit ) = $ssh->cmd('sudo ls -l /etc/security');
    croak 'Failed to run remote command (' . $exit . '): $!' if $exit;

    my $handle = $self->cmd_output;
    foreach my $eline ( split $/, $err ) {
        print $handle 'ERR: ' . $eline . "\n";
    }
    foreach my $oline ( split $/, $out ) {
        print $handle '> ' . $oline . "\n";
    }
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

