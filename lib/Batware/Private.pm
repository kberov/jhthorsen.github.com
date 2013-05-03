package Batware::Private;

=head1 NAME

Batware::Private - Browse files, but not folders

=cut

use Mojo::Base 'Batware::Files';

=head1 METHODS

=head2 tree

Will show a list of files.

=cut

sub tree {
  my $self = shift;
  my $url_path = $self->_url_path;
  my $disk_path = $self->_root_path($url_path);
  my @files;

  $self->stash(
    files => \@files,
    url_path => $self->_tree_path($url_path),
    parent_path => '',
    show_upload => -e "$disk_path/.upload",
  );

  if($self->req->method eq 'POST') {
    my @files = $self->req->upload('file');
    $self->app->log->info("files=@files");
    $_->move_to("$disk_path/" .$_->filename) for grep { $_->filename } @files;
  }

  length $url_path > 10 or return $self->render_not_found;

  $self->_loop_files($disk_path, sub {
    my($file, $ext, $type) = @_;
    push @files, {
      basename => $file,
      shortname => 15 <= length $file ? substr($file, 0, 12) .'...' : $file,
      ext => $ext,
      type => $type,
      url => $type eq 'text/html' ? $self->_raw_path($url_path, $file)
           :                        $self->_show_path($url_path, $file),
    };
  });

  $self->render(template => 'files/tree');
}

sub _root_path { join '/', shift->app->config->{Files}{private_path}, grep { length } @_ }
sub _raw_path { shift; join '/', '/private/raw', grep { length } @_ }
sub _show_path { shift; join '/', '/private/show', grep { length } @_ }
sub _tree_path { shift; join '/', '/private/tree', grep { length } @_ }

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
