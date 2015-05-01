package Batware::Docsis;

=head1 NAME

Batware::Docsis - Edit DOCSIS config files

=cut

use Mojo::Base 'Mojolicious::Controller';
use DOCSIS::ConfigFile::Translator;
use Batware::Model::Docsis;

=head1 METHODS

=head2 edit

Used to either save, download or upload a DOCSIS config file.

=cut

sub edit {
  my $self = shift;
  my $action = $self->param('action') || 'download';

  return $self->_upload if $self->req->upload('file');
  return $self->_download if $action eq 'download';
  return $self->_save if $action eq 'save';
  return $self->render_not_found;
}

sub _download {
  my $self = shift;
  my $docsis = $self->_model;

  if (my $binary = $docsis->to_binary) {
    $self->res->headers->content_disposition(sprintf 'attachment; filename=%s', $docsis->filename);
    $self->render(data => $binary, format => 'binary');
  }
  else {
    $self->render(text => "Could not convert config to binary\n", code => 400);
  }
}

sub _save {
  my $self = shift->render_later;
  my $docsis = $self->_model;

  unless ($self->to_binary) {
    return $self->render(text => "Could not convert config to binary\n", code => 400);
  }

  $self->delay(
    sub { $docsis->load(shift->begin); },
    sub {
      my ($delay, $err) = @_;
      $docsis->$_($self->param($_)) for qw( config filename shared_secret );
      $docsis->save($delay->begin);
    },
    sub {
      my ($delay, $err) = @_;
      die $err if $err;
      $self->render(docsis => $docsis, report => 'Saved config.');
    },
  );
}

sub _upload {
  my $self = shift;
  my $file = $self->req->upload('file');
  my $docsis = $self->_model;

  unless (eval { $docsis->from_binary($file->slurp) }) {
    return $self->render(report => 'Could not parse binary config file.')->app->log->warn("from_binary: $@");
  };

  $self->param(config => $docsis->config);
  $self->param(filename => $file->filename);
  $self->stash(report => 'User config file was loaded.')
}

=head2 load

Used to load config from database by id.

=cut

sub load {
  my $self = shift->render_later;
  my $docsis = $self->_model;

  my $render = sub {
    my($obj, $err, $docsis) = @_;
    die $err if $err;
    $self->param(filename => $docsis->filename);
    $self->param(shared_secret => $docsis->shared_secret);
    $self->param(config => $docsis->config);
    $self->render(
      report => 'Editing config.',
      template => 'docsis/edit',
      format => 'html', # Why does render_partial() mess this up?
    );
  };

  if($docsis->id eq 'example') {
    $docsis->config($self->render_to_string(template => 'docsis/example', format => 'txt'));
    $docsis->filename('example.bin');
    $self->$render('', $docsis);
  }
  else {
    $self->delay(
      sub { $docsis->load(shift->begin) },
      sub { shift; $self->$render(@_) },
    );
  }
}

sub _model {
  my $self = shift;
  my $docsis = Batware::Model::Docsis->new(db => shift->model->db, @_);

  $docsis->config($self->param('config')) if $self->param('config');
  $docsis->filename($self->param('filename')) if $self->param('filename');
  $docsis->id($self->param('id') || join '-', time, int rand 10000);
  $docsis;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
