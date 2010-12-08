use Test::More tests => 2;

use strict;

package OneScript;

use Moose;
with 'WAS::Script';

1;

package main;

eval { my $ss = OneScript->new; };
ok($@);

my $s = OneScript->new(
    name => 'myscript',
    path => '/somewhere/over/the/rainbow/script.py'
);
ok($s);

