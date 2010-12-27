use Test::More tests => 3;

use WAS::App::Expander;

eval { my $err = WAS::App::Expander->new; };
ok($@);

my $e = WAS::App::Expander->new( earfile => 'examples/teste.zip' );
ok($e);

diag( 'dest=' . $e->dest );
ok( $e->dest eq 'examples/teste_zip' );
