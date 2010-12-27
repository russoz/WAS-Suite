use Test::More tests => 3;

use strict;

use WAS::Profile;

eval { my $ss = WAS::Profile->new; };
ok($@);

my $s = WAS::Profile->new(
    name => 'AppSrv01',
    path => '/somewhere/over/the/rainbow',
);
ok($s);
ok( $s->is_local );

