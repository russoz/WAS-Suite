use Test::More tests => 3;

use File::Path qw(remove_tree);
use WAS::App::Expander;

my $e = WAS::App::Expander->new( earfile => 'examples/test2.zip' );
ok($e);

$e->expand;
ok( -f 'examples/test2_zip/one.txt' );
ok( -f 'examples/test2_zip/test.zip/somewhere/over/the/rainbow/pot-of-gold.txt'
);

remove_tree('examples/test2_zip');
