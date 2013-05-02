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

our $VERSION = '0.01';

=head1 METHODS

=head2 startup

Called to set up the routes.

=cut

sub startup {
  my $self = shift;
  my $config = $self->plugin('config');
  my $r = $self->routes;

  $self->plugin(Mail => $config->{Mail});

  $r->get('/')->to(template => 'index');
  $r->get('/contact')->to(template => 'contact', report => '')->name('contact');
  $r->post('/contact')->to(cb => \&_post_contat_form);
}

sub _post_contat_form {
  my $c = shift;

  eval {
    $c->param('message') or die 'No message?';
    $c->mail(
      to => $c->app->config->{Mail}{receiver},
      from => $c->param('email') || die('Your email is missing.'),
      subject => $c->param('subject') || die('Subject need to be filled out.'),
      template => 'contact',
      format => 'mail',
    );
    $c->stash(report => 'Message was sent!');
  } or do {
    my $e = $@;
    $c->app->log->error($e);
    $e =~ s/ at \S+.*//s;
    $c->stash(report => $e || 'Could not send message!');
  };
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;