package Batware::Files;

=head1 NAME

Batware::Files - Browse files

=cut

use feature 'switch';
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Asset::File;
use File::Basename;
use File::MimeInfo::Magic;
use Image::EXIF;
use Image::Imlib2;
use Mojolicious::Static;
use constant IMAGES_PR_PAGE => 60;

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
      size => -s "$disk_path/$file",
      ext => $ext,
      type => $type,
      url => $type eq 'directory' ? $self->_tree_path($url_path, $file)
           : $type eq 'text/html' ? $self->_raw_path($url_path, $file)
           :                        $self->_show_path($url_path, $file),
    };
  });
}

=head2 gallery

Render a gallery instead of plain file list.

=cut

sub gallery {
  my $self = shift;
  my $offset = $self->param('offset') || 0;
  my $url_path = $self->_url_path;
  my $disk_path = $self->_root_path($url_path);
  my $parent_path = '';
  my $n = 0;
  my @files;

  $parent_path = $self->_tree_path(dirname $url_path) if $url_path;
  $parent_path =~ s!\.$!!;

  $self->stash(
    files => \@files,
    name => basename($url_path),
    parent_path => $parent_path,
    url_path => $self->_tree_path($url_path),
  );

  $self->_loop_files($disk_path, sub {
    my($file, $ext, $type) = @_;
    return 1 unless $type =~ m!^image/!;
    return 1 if $n++ < $offset;
    push @files, {
      basename => Mojo::Util::decode('UTF-8', $file),
      size => -s "$disk_path/$file",
      src => $self->_thumb_path($url_path, $file),
      url => $type eq 'directory' ? $self->_tree_path($url_path, $file) : $self->_show_path($url_path, $file),
    };
    return @files < IMAGES_PR_PAGE;
  });

  $self->render(template => 'files/gallery');
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
  return $self->render(template => 'files/video')   if $type =~ m!^video/!;
  return $self->raw;
}

=head2 raw

Will serve a file in raw format.

=cut

sub raw {
  my $self = shift;
  my $url_path = $self->_url_path;
  my($ext, $type) = $self->_extract_extension_and_filetype($self->_root_path, $url_path);

  $self->res->headers->content_type($type);
  $self->res->headers->content_disposition(qq(attachment; filename="@{[basename $url_path ]}")) if $self->param('download');

  if($type !~ m!/!) {
    $self->render(text => 'Unknown file format', format => 'txt');
  }
  if($type =~ m!^image! and not $self->param('download')) {
    $self->_raw_image(join '/', $self->_root_path, $url_path);
  }
  else {
    my $static = Mojolicious::Static->new(paths => [$self->_root_path]);
    $static->serve($self, $url_path) or return $self->render(text => 'Unable to serve file', format => 'txt');
    $self->rendered;
  }
}

sub _raw_image {
  my($self, $path) = @_;
  my $url_path = $self->_url_path;
  my $exif = Image::EXIF->new($path);
  my $orientation = $exif->get_image_info->{'Image Orientation'} || '';
  my $static;

  given($orientation) {
    when(/^.*left.*bottom/i)  { $orientation = 3 }
    when(/^.*bottem.*right/i) { $orientation = 2 }
    when(/^.*right.*top/i)    { $orientation = 1 }
    default                   { $orientation = 0 }
  }

  if($orientation) {
    eval {
      my $path = $self->app->config->{Files}{thumb_path};
      my $md5 = Mojo::Util::md5_sum($url_path);
      unless(-e "$path/$md5") {
        my $t = Image::Imlib2->load(join '/', $self->_root_path, $url_path);
        $t->image_orientate($orientation);
        $t->save("$path/$md5");
      }
      $static = Mojolicious::Static->new(paths => [$path]);
      $url_path = $md5;
    } or do {
      $self->app->log->error("image_orientate: $@");
    };
  }

  $static ||= Mojolicious::Static->new(paths => [$self->_root_path]);
  $static->serve($self, $url_path) or return $self->render(text => 'Unable to serve file', format => 'txt');
  $self->rendered;
}

=head2 thumb

Returns a thumb of a image file.

=cut

sub thumb {
  my $self = shift;
  my $static = Mojolicious::Static->new(paths => [$self->app->config->{Files}{thumb_path}]);
  my $url_path = $self->_url_path;
  my $md5 = Mojo::Util::md5_sum($url_path) .'_100.jpg';
  my $thumb = join '/', $static->paths->[0], $md5;

  unless(-e $thumb) {
    eval {
      my $t = Image::Imlib2->load(join '/', $self->_root_path, $url_path);
      $t->image_set_format('jpeg');
      $t->create_scaled_image(100, 100)->save($thumb);
      $t;
    } or do {
      # TODO: Should probably render default image
      $self->render_exception($@);
    };
  }

  $static->serve($self, $md5) or return $self->render(text => 'Unable to serve file', format => 'txt');
  $self->res->headers->content_type('image/jpeg');
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
sub _thumb_path { shift; join '/', '/files/thumb', grep { length } @_ }

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
    last unless $cb->($file, $self->_extract_extension_and_filetype($disk_path, $file));
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
