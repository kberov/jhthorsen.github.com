package Batware;

=head1 NAME

Batware - My personal homepage

=head1 VERSION

0.01

=head1 SYNOPSIS

  $ morbo script/batware
  $ hypnotoad script/batware
  $ ./script/batware daemon
  $ ...

=head1 DESCRIPTION

This is the codebare for L<http://thorsen.pm>.

=cut

use Mojo::Base 'Mojolicious';
use Mojo::Redis;

our $VERSION = '0.01';

=head1 HELPERS

=head2 eval_code

  $code_return_value = $c->eval_code(CODE);

Used to eval a code ref and set "report" in status on error.

=cut

sub eval_code {
  my($c, $cb) = @_;
  my $res;

  eval {
    $res = $c->$cb;
    1;
  } or do {
    my $e = $@;
    $c->app->log->error($e);
    $e =~ s/ at \S+.*//s;
    $c->stash(report => $e || 'Could not send message!');
  };

  $res;
}

=head2 redis

Returns an instance of L<Mojo::Redis>.

=cut

sub redis {
  my $c = shift;
  $c->stash->{redis} ||= do { Mojo::Redis->new($c->app->config->{Redis}) };
}

=head1 METHODS

=head2 startup

Called to set up the routes.

=cut

sub startup {
  my $self = shift;
  my $config = $self->plugin('config');
  my $r = $self->routes;

  $self->plugin(Mail => $config->{Mail});
  $self->helper(eval_code => \&eval_code);
  $self->helper(redis => \&redis);

  $r->get('/')->to(template => 'index');
  $r->get('/about/cv')->to(template => 'curriculum_vitae');
  $r->get('/contact')->to(template => 'contact', report => '')->name('contact');
  $r->post('/contact')->to(cb => \&_post_contact_form);
  $r->get('/trips')->to(template => 'trips')->name('trips');
  $r->get('/404')->to(template => 'not_found.production');
  $r->get('/500')->to(template => 'exception.production');

  $r->get('/files')->to('files#tree', url_path => '');
  $r->get('/files/tree/(*url_path)')->to('files#tree', url_path => '')->name('files_tree');
  $r->get('/files/show/*url_path')->to('files#show')->name('files_show');
  $r->get('/files/raw/*url_path')->to('files#raw')->name('files_raw');
  $r->get('/files/*url_path')->to('files#redirect');

  $r->get('/gallery/show/*url_path')->to('gallery#show')->name('gallery_show');
  $r->get('/gallery/raw/*url_path')->to('gallery#raw')->name('gallery_raw');
  $r->get('/gallery/thumb/*url_path')->to('gallery#thumb')->name('gallery_raw');
  $r->get('/gallery/*url_path')->to('gallery#tree', url_path => '')->name('gallery_tree');

  $r->any('/private/tree/*url_path')->to('private#tree')->name('private_tree');
  $r->get('/private/show/*url_path')->to('private#show')->name('private_show');
  $r->get('/private/raw/*url_path')->to('private#raw')->name('private_raw');
  $r->any('/private/*url_path')->to('private#tree');

  $r->get('/service/docsis')->to(cb => sub { $_[0]->redirect_to('docsis') });
  $r->get('/services/docsis')->to(cb => sub { $_[0]->redirect_to('docsis') });
  $r->get('/docsis-editor')->to(template => 'docsis/edit', report => '')->name('docsis');
  $r->get('/docsis-editor/syminfo')->to(template => 'docsis/syminfo')->name('docsis_syminfo');
  $r->post('/docsis-editor')->to('docsis#edit');
  $r->get('/docsis-editor/:id')->to('docsis#load')->name('docsis_load');

  $r->get('/tt')->to(cb => sub { shift->redirect_to('time_tracker') });
  $r->any('/time-tracker')->to('tracker#index')->name('time_tracker');
}

sub _post_contact_form {
  my $c = shift;

  $c->eval_code(sub {
    $c->param('message') or die 'No message?';
    $c->mail(
      to => $c->app->config->{Mail}{receiver},
      from => $c->param('email') || die('Your email is missing.'),
      subject => $c->param('subject') || die('Subject need to be filled out.'),
      template => 'contact',
      format => 'mail',
    );
    $c->stash(report => 'Message was sent!');
  });
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
