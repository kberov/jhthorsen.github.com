package Batware::Command::user;

=head1 NAME

Batware::Command::user - Mojo command to add/modify users.

=cut

use Mojo::Base 'Mojolicious::Command';
use Term::ReadKey;

=head1 ATTRIBUTES

=head2 description

=cut

has description => 'Mojo command to add/modify users.';

=head2 usage

=cut

has usage => <<"USAGE";
Usage: $0 user <username>

USAGE

=head1 METHODS

=head2 run

=cut

sub run {
  my $self = shift;
  my $username = shift or die $self->usage;
  my %data = map { $_ => 1 } qw/ password /;

  for my $k (sort keys %data) {
    my $value = '';
    print ucfirst "$k: ";

    ReadMode 'cbreak' if $k eq 'password';
    while(my $key = ReadKey) {
      last if $key eq "\n";
      $value .= $key;
    }

    ReadMode 'restore';
    print "\n";

    if(!$value) {
      delete $data{$k};
      next;
    }
    elsif($k eq 'password') {
      $data{$k} = crypt $value, time .$$ .rand 100000;
    }
    else {
      $data{$k} = $value;
    }
  }

  $self->app->redis->hmset("username:$username", %data, sub {
    Mojo::IOLoop->stop;
    print "Saved!\n";
  });

  Mojo::IOLoop->start;
  return 0;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
