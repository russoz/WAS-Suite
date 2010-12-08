use Test::More tests => 2;

use strict;

package OneApp;

use Moose;
with 'WAS::App';

1;

package main;

eval { my $aa = OneApp->new; };
ok($@);

my $a = OneApp->new( name => 'myapp' );
ok($a);

