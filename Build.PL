use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name       => 'WAS::Remote::App',
    license           => 'perl',
    dist_author       => 'Alexei Znamensky <russoz@cpan.org>',
    dist_version_from => 'lib/WAS/Remote/App.pm',
    requires          => {
        'autodie'    => 0,
        'DateTime'   => 0,
        'File::Copy' => 0,
        'File::Path' => 0,
        'File::Spec' => 0,
        'Moose'      => 0,
        'Test::More' => 0,
        'Try::Tiny'  => 0,
        'version'    => 0,
    },
    add_to_cleanup => ['WAS-Remote-App-*'],
);

$builder->create_build_script();
