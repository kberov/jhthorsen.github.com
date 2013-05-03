use Test::More;
use Test::Mojo;

$ENV{PWD} = 't/data';

my $t = Test::Mojo->new('Batware');

$t->get_ok('/private')->status_is(404);
$t->get_ok('/private/12345678901234567890')->status_is(404);

$t->get_ok('/private/098765432123456')
  ->status_is(200)
  ->text_is('a[href="/private/tree/"]', 'Back')
  ->text_is('a[href="/private/show/098765432123456/test.txt"]', 'test.txt')
  ->text_is('a[href="/private/tree/098765432123456/subdir"]', 'subdir')
  ;

$t->get_ok('/private/show/098765432123456/test.txt')
  ->text_like('pre.prettyprint', qr{hello world!})
  ->status_is(200);

done_testing;
