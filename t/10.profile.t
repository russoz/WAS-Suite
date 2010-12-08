use Test::More tests => 3;

use strict;

package OneProfile;

use Moose;
with 'WAS::Profile';

1;

package main;

eval { my $ss = OneProfile->new; };
ok($@);

my $s = OneProfile->new( name => 'AppSrv01',
path => '/somewhere/over/the/rainbow' );
ok($s);
ok( $s->is_local );

