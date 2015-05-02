package Batware::Model::Docsis;

=head1 NAME

Batware::Model::Docsis - Store docsis config files

=head1 VERSION

0.01

=head1 DESCRIPTION

L<Batware::Model::Docsis> is a model for storing docsis config files.

=cut

use Mojo::Base -base;
use Mojo::Message::Response;
use Mojo::Util;
use DOCSIS::ConfigFile::Translator;

=head1 COLUMNS

=head2 config

=head2 filename

=head2 id

=head2 shared_secret

=head2 timestamp

=cut

has id            => undef;
has config        => '';
has filename      => 'default.bin';
has shared_secret => '';
has timestamp     => time;

has _location => sub { die };

=head1 METHODS

=head2 from_binary

  $self = $self->from_binary($bytes);

Will convert C<$bytes> to text and save it in L</config>.

=cut

sub from_binary {
  my $self = shift;
  my $config = DOCSIS::ConfigFile::Translator->binary_to_text(shift);

  $self->config($config);
}

=head2 load

=cut

sub load {
  my ($self, $cb) = @_;
  my $file = File::Spec->catfile($self->_location, $self->id);
  my $msg;

  local $@;
  eval {
    $msg = Mojo::Message::Response->new;
    $msg->parse(Mojo::Util::slurp($file));
    $self->{$_} = $msg->headers->header($_) for @{$msg->headers->names};
    $self->timestamp(Mojo::Date->new(delete $self->{Date} || time)->epoch);
    $self->config($msg->body);
  };

  $self->$cb('');
  $self;
}

=head2 save

=cut

sub save {
  my ($self, $cb) = @_;
  my @cols = qw( id filename shared_secret );
  my $msg;

  local $@;
  eval {
    $msg = Mojo::Message::Response->new(code => 200);
    $msg->headers->header($_ => $self->{$_} // '') for @cols;
    $msg->headers->date(Mojo::Date->new($self->timestamp)->to_string);
    $msg->body($self->config);
    Mojo::Util::spurt($msg->to_string, File::Spec->catfile($self->_location, $self->id));
  };

  $self->$cb($@ || '');
  $self;
}

=head2 to_binary

  $bytes = $self->to_binary;

Tries to convert L</config> into a binary data, using
L<DOCSIS::ConfigFile>.

Returns undef and sets C<$@> on error.

=cut

sub to_binary {
  my $self = shift;
  eval { DOCSIS::ConfigFile::Translator->text_to_binary($self->shared_secret, $self->config) };
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
