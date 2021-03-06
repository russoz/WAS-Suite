use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name       => 'WAS::Suite',
    license           => 'perl',
    dist_author       => 'Alexei Znamensky <russoz@cpan.org>',
    dist_version_from => 'lib/WAS/Suite.pm',
    requires          => {
        'Net::SFTP'      => 0,
        'Net::SSH::Perl' => 0,
        'autodie'        => 0,
        'common::sense'  => 0,
        'DateTime'       => 0,
        'Archive::Zip' => 0,
        'Cwd' => 0,
        'File::Basename' => 0,
        'File::Copy'     => 0,
        'File::Find'     => 0,
        'File::Path'     => 0,
        'File::Spec::Functions'     => 0,
        'Moose'          => 0,
        'MooseX::GetOpt'          => 0,
        'MooseX::Types::Path::Class'          => 0,
        'Test::More'     => 0,
        'version'        => 0,
    },
    add_to_cleanup => ['WAS-Suite-*'],
);

$builder->create_build_script();
