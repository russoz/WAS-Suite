package WAS::App;

use Moose;

use version; our $VERSION = qv('0.0.10');

# websphere-related attributes
has 'name' => ( is => 'ro', isa => 'Str', required => 1, );

no Moose;
__PACKAGE__->meta->make_immutable;

1;

