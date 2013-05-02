package Batware::Docsis;

=head1 NAME

Batware::Docsis - Edit DOCSIS config files

=cut

use Mojo::Base 'Mojolicious::Controller';
use DOCSIS::ConfigFile::Translator;

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
  my $filename = $self->param('filename') || 'default.bin';
  my $binary = $self->_compile_binary or return;

  $self->res->headers->content_disposition(sprintf 'attachment; filename=%s', $filename);
  $self->render_data($binary, format => 'binary');
}

sub _save {
  my $self = shift->render_later;
  my $id = $self->param('id') || join '-', time, int rand 10000;

  $self->_compile_binary or return;
  $self->redis->sadd(docsis => $id);
  $self->redis->set("docsis:$id:config" => scalar $self->param('config'));
  $self->redis->hmset(
    "docsis:$id:meta" => (
      timestamp => time,
      filename => $self->param('filename') || 'default.bin',
      shared_secret => $self->param('shared_secret') || '',
    ),
    sub {
      $self->render(report => "Saved config '$id'.");
    },
  );
}

sub _upload {
  my $self = shift;
  my $file = $self->req->upload('file');
  my $config = $file->slurp or return $self->render(report => 'No config in config file?');

  $self->eval_code(sub {
    $self->param(config => DOCSIS::ConfigFile::Translator->binary_to_text($config));
    $self->param(filename => $file->filename);
    $self->stash(report => 'User config file was loaded.')
  });
}

=head2 load

Used to load config from database by id.

=cut

sub load {
  my $self = shift->render_later;
  my $id = $self->param('id');

  my $render = sub {
    my($obj, $meta, $config) = @_;
    $self->param(filename => $meta->{filename} // '');
    $self->param(shared_secret => $meta->{shared_secret} // '');
    $self->param(config => $config);
    $self->render(
      report => "Editing config '$id'.",
      template => 'docsis/edit',
      format => 'html', # Why does render_partial() mess this up?
    );
  };

  if($id eq 'example') {
    $self->$render(
      { filename => 'example.bin' },
      $self->render_partial('docsis/example', format => 'txt'),
    );
  }
  else {
    $self->redis->execute(
      [ hgetall => "docsis:$id:meta" ],
      [ get => "docsis:$id:config" ],
      $render,
    );
  }
}

sub _compile_binary {
  my $self = shift;
  my $config = $self->param('config');
  my $shared_secret = $self->param('shared_secret');

  $self->eval_code(sub {
    DOCSIS::ConfigFile::Translator->text_to_binary($shared_secret, $config);
  });
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
