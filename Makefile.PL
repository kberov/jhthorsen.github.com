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
    'Config::General'                => '2.51',
    'DBD::Pg'                        => '3.5.1',
    'File::HomeDir'                  => '1.00',
    'DOCSIS::ConfigFile'             => '0.63',
    'File::MimeInfo::Magic'          => '0.16',
    'Mojolicious'                    => '4.30',
    'Mojolicious::Plugin::AssetPack' => '0.05',
    'Mojolicious::Plugin::Mail'      => '1.00',
    'Mojo::Pg'                       => '2.05',
  },
  test => {
    TESTS => 't/*.t',
  },
);
