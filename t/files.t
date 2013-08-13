use utf8;
use Test::More;
use Test::Mojo;

$ENV{PWD} = 't/data';

my $t = Test::Mojo->new('Batware');

$t->get_ok('/files')
  ->status_is(200)
  ->text_is('a[href="/files/show/%C3%A6%C3%B8%C3%A5.txt"]', 'æøå.txt')
  ->text_is('a[href="/files/show/other.pm"]', 'other.pm')
  ;

$t->get_ok('/files/show/æøå.txt')
  ->status_is(200)
  ->text_like('pre.prettyprint', qr{Hello æøå!})
  ;

$t->get_ok('/files/show/other.pm')
  ->status_is(200)
  ->text_like('pre.prettyprint', qr{=head1 NAME}) # TODO: Show perldoc instead
  ;

done_testing;