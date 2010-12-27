use Test::More tests => 2;

use strict;
use WAS::Script;

eval { my $ss = WAS::Script->new; };
ok($@);

my $s = WAS::Script->new(
    name => 'myscript',
    path => '/somewhere/over/the/rainbow/script.py'
);
ok($s);

