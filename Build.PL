use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'WAS::Remote::Install',
    license             => 'perl',
    dist_author         => 'Alexei Znamensky <russoz@cpan.org>',
    dist_version_from   => 'lib/WAS/Remote/Install.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'WAS-Remote-Install-*' ],
);

$builder->create_build_script();
