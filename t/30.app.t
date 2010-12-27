use Test::More tests => 2;

use strict;
use WAS::App;

eval { my $aa = WAS::App->new; };
ok($@);

my $a = WAS::App->new( name => 'myapp' );
ok($a);

