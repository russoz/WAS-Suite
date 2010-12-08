use Test::More tests => 2;

use strict;

package OneServer;

use Moose;
with 'WAS::Server';

1;

package main;

eval { my $ss = OneServer->new; };
ok($@);

my $s = OneServer->new( name => 'server1', );
ok($s);

