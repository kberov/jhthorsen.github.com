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
    'Config::General' => '2.51',
    'DBD::SQLite' => 1.37,
    'DOCSIS::ConfigFile' => '0.63',
    'File::MimeInfo::Magic' => '0.16',
    'Image::EXIF' => 2.01,
    'Image::Imlib2' => 2.03,
    'Mojolicious' => '3.91',
    'Mojolicious::Plugin::Mail' => '0.94',
    'Mojolicious::Plugin::Shotwell' => '0.01',
  },
  test => {
    TESTS => 't/*.t',
  },
);
