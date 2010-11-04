use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'WAS::Remote::Install',
    AUTHOR              => 'Alexei Znamensky <russoz@cpan.org>',
    VERSION_FROM        => 'lib/WAS/Remote/Install.pm',
    ABSTRACT_FROM       => 'lib/WAS/Remote/Install.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WAS-Remote-Install-*' },
);
