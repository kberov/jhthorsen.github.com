use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME => 'Batware',
  VERSION => '1.0',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  EXE_FILES => ['script/batware'],
  PREREQ_PM => {
    'Config::General' => '2.51',
    'DOCSIS::ConfigFile' => '0.63',
    'File::MimeInfo::Magic' => '0.16',
    'Mojolicious' => '3.91',
    'Mojolicious::Plugin::Mail' => '0.94',
  },
  test => {
    TESTS => 't/*.t',
  },
);
