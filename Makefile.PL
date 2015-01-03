use strict;
use warnings;
use ExtUtils::MakeMaker;

# sudo apt-get install libimage-exif-perl libimage-imlib2-perl

WriteMakefile(
  NAME => 'Batware',
  VERSION => '1.0',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  EXE_FILES => ['script/batware'],
  PREREQ_PM => {
    'Config::General' => 2.51,
    'DBD::SQLite' => 1.37,
    'DOCSIS::ConfigFile' => 0.63,
    'File::MimeInfo::Magic' => 0.16,
    'Imager' => 0.98,
    'Mojo::Redis' => 0.90,
    'Mojolicious' => 4.30,
    'Mojolicious::Plugin::AssetPack' => 0.05,
    'Mojolicious::Plugin::Mail' => 1.00,
    'Mojolicious::Plugin::Shotwell' => 0.0405,
  },
  test => {
    TESTS => 't/*.t',
  },
);
