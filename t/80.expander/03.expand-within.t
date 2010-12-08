use Test::More tests => 3;

use WAS::App::Expander;

my $e = WAS::App::Expander->new( earfile => 'examples/test2.zip' );
ok($e);

$e->expand;
ok( -f 'examples/test2_zip/one.txt' );
ok( -f 'examples/test2_zip/teste.zip/somewhere/over/the/rainbow/pot-of-gold.txt' );
