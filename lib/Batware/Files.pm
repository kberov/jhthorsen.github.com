package Batware::Files;

=head1 NAME

Batware::Files - Browse files

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mojo::Asset::File;
use File::Basename;
use File::MimeInfo::Magic;
use Mojolicious::Static;

=head1 METHODS

=head2 tree

Will show a list of files.

=cut

sub tree {
  my $self = shift;
  my $url_path = $self->_url_path;
  my $disk_path = $self->_root_path($url_path);
  my $parent_path = '';
  my @files;

  $parent_path = $self->_tree_path(dirname $url_path) if $url_path;
  $parent_path =~ s!\.$!!;

  $self->stash(
    files => \@files,
    parent_path => $parent_path,
    url_path => $self->_tree_path($url_path),
  );

  $self->_loop_files($disk_path, sub {
    my($file, $ext, $type) = @_;
    push @files, {
      basename => Mojo::Util::decode('UTF-8', $file),
      shortname => 15 <= length $file ? substr($file, 0, 12) .'...' : $file,
      ext => $ext,
      type => $type,
      url => $type eq 'directory' ? $self->_tree_path($url_path, $file)
           : $type eq 'text/html' ? $self->_raw_path($url_path, $file)
           :                        $self->_show_path($url_path, $file),
    };
  });
}

=head2 show

Will show a single file embedded in a template.

=cut

sub show {
  my $self = shift;
  my $url_path = $self->_url_path;
  my $disk_path = $self->_root_path($url_path);
  my($ext, $type) = $self->_extract_extension_and_filetype($disk_path);

  $self->stash(
    basename => basename($disk_path),
    file => Mojo::Asset::File->new(path => $disk_path),
    dir_path => $self->_tree_path(dirname $url_path),
    raw_path => $self->_raw_path($url_path),
    url_path => $self->_show_path($url_path),
  );

  return $self->render(template => 'files/include') if $type eq 'include';
  return $self->render(template => 'files/text')    if $type =~ m!^text/!;
  return $self->render(template => 'files/image')   if $type =~ m!^image/!;
  return $self->raw;
}

=head2 raw

Will serve a file in raw format.

=cut

sub raw {
  my $self = shift;
  my $url_path = $self->_url_path;
  my $static = Mojolicious::Static->new(paths => [$self->_root_path]);
  my($ext, $type) = $self->_extract_extension_and_filetype($static->paths->[0], $url_path);

  $type =~ m!/! or return $self->render_data('Unknown file format', format => 'txt');
  $static->serve($self, $url_path) or return $self->render_data('Unable to serve file', format => 'txt');
  $self->res->headers->content_type($type);
  $self->rendered;
}

=head2 redirect

Used to be backward compat with older urls.

=cut

sub redirect {
  my $self = shift;
  my $url_path = $self->_url_path;

  if(-d $self->_root_path($url_path)) {
    $self->redirect_to(files => url_path => $url_path);
  }
  else {
    $self->redirect_to(files_show => url_path => $url_path);
  }
}

sub _root_path { join '/', shift->app->config->{Files}{public_path}, grep { length } @_ }
sub _raw_path { shift; join '/', '/files/raw', grep { length } @_ }
sub _show_path { shift; join '/', '/files/show', grep { length } @_ }
sub _tree_path { shift; join '/', '/files/tree', grep { length } @_ }

sub _extract_extension_and_filetype {
  my $self = shift,
  my $path = join '/', @_;
  my($ext, $type);

  return('', 'directory') if -d $path;

  $ext = lc(($path =~ m!\.(\w+)$!)[0] || '');
  $type = $ext ~~ [qw/ ep pm pl PL sh t /] ? 'text/plain'
        : $ext eq 'js' ? 'text/javascript'
        : $ext eq 'tt' ? 'include'
        : $ext eq 'css' ? 'text/css'
        : $ext =~ /html$/ ? 'text/html'
        : mimetype $path;

  return($ext, $type || 'unknown');
}

sub _loop_files {
  my($self, $disk_path, $cb) = @_;

  opendir my $DH, $disk_path or return $self->render_not_found;

  for my $file (sort readdir $DH) {
    next if $file =~ /^\./;
    next if !-r "$disk_path/$file";
    $cb->($file, $self->_extract_extension_and_filetype($disk_path, $file));
  }
}

sub _url_path {
  my $self = shift;
  my $url_path = $self->param('url_path');

  $url_path =~ s!^/!!;
  $url_path =~ s!/$!!;
  $url_path =~ s!//!/!g;
  $url_path =~ s!\.\.!!g;
  $url_path;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
