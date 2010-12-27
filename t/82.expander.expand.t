use Test::More tests => 3;

use File::Path qw(remove_tree);
use WAS::App::Expander;

my $e = WAS::App::Expander->new( earfile => 'examples/test.zip' );
ok($e);

$e->expand;
ok( -f 'examples/test_zip/some-file.txt' );
ok( -f 'examples/test_zip/somewhere/over/the/rainbow/pot-of-gold.txt' );

remove_tree('examples/test_zip');

