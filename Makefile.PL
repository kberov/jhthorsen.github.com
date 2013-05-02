use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME => 'Batware',
  VERSION => '1.0',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  EXE_FILES => ['script/batware'],
  PREREQ_PM => {
    'Mojolicious' => '3.91',
  },
  test => {
    TESTS => 't/*.t',
  },
);
