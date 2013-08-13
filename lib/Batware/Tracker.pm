package Batware::Tracker;

=head1 NAME

Batware::Tracker - Time tracker on web

=cut

use Mojo::Base 'Mojolicious::Controller';

=head1 METHODS

=head2 index

=cut

sub index {
  my $self = shift;

  $self->stash(
    items => [
        { tags => join(', ', qw/ work important /), start => time - 7200, stop => time - 6000 },
        { tags => join(', ', qw/ other /), start => time - 17200, stop => time - 15001 },
        { tags => join(', ', qw/ fun /), start => time - 27200, stop => time - 25020 },
    ],
    tracking => {
      tags => [qw/ work important /],
      start => 1368534739,
    },
  );
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
