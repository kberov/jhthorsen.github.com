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
  my $r = $self->routes;

  $r->get('/')->to(template => 'index');
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;