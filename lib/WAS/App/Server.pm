package WAS::App::Server;

use Moose;
use common::sense;

use version; our $VERSION = qv('0.0.5');

use File::Spec::Functions;

# websphere-related attributes
has 'server_name'  => ( is => 'ro', isa => 'Str', required  => 1, );
has 'profile_path' => ( is => 'ro', isa => 'Str', required  => 1, );
has 'host'         => ( is => 'ro', isa => 'Str', predicate => 'has_host' );

has 'wsadmin' => ( is => 'ro', isa => 'Str', default => 'wsadmin.sh', );
has 'wsadmin_args' => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [qw/-lang jython/] },
);

sub is_local {
    my $self = shift;
    return 1 unless $self->has_host;
    return 1 if $self->was_host eq 'localhost';
    return 1 if $self->was_host =~ /^localhost\./;
    eval {
        use Sys::Hostname;
        return 1 if $self->was_host eq hostname;
    } eval {
        use Net::Domain qw/hostname hostfqdn/;
        return 1 if $self->was_host eq hostname();
        return 1 if $self->was_host eq hostfqdn();
    } return 0;
}

sub wsadmin_path {
    my $self = shift;
    return catfile( $self->profile_path, 'bin', $self->wsadmin );
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;    # Magic true value required at end of module

