#!/usr/bin/perl

use WAS::App::Install;

my $app = WAS::App::Install->new(
    {
        local_base_dir => './tmp/remote-was',
        rem_host       => 'washost',
        rem_user       => 'joedoe',

        #use_sudo => 1,
        #sudo_user => 'was',

        was_app_name     => 'myApp',
        was_profile_path => '/usr/IBM/WebSphere/AppServer/profiles/AppSrv01',
    }
);

my $script = $app->prepare_files('myApp.ear');
$app->prepare_remote_install();
$app->do_remote_install();
