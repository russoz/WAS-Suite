use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name       => 'WAS::App::Install',
    license           => 'perl',
    dist_author       => 'Alexei Znamensky <russoz@cpan.org>',
    dist_version_from => 'lib/WAS/App/Install.pm',
    requires          => {
        'Net::SFTP'      => 0,
        'Net::SSH::Perl' => 0,
        'autodie'        => 0,
        'common::sense'  => 0,
        'DateTime'       => 0,
        'File::Copy'     => 0,
        'File::Path'     => 0,
        'File::Spec'     => 0,
        'Moose'          => 0,
        'Test::More'     => 0,
        'version'        => 0,
    },
    add_to_cleanup => ['WAS-App-Install-*'],
);

$builder->create_build_script();
