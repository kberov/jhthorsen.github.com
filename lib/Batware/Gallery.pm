package Batware::Gallery;

=head1 NAME

Batware::Gallery - Browse images

=cut

use feature 'switch';
use Mojo::Base 'Batware::Files';
use Mojo::Asset::File;
use File::Basename;
use File::MimeInfo::Magic;
use Image::EXIF;
use Image::Imlib2;
use Mojolicious::Static;

=head1 METHODS

=head2 tree

Render a gallery instead of plain file list.

=cut

sub tree {
  my $self = shift;
  my $url_path = $self->_url_path;
  my $disk_path = $self->_root_path($url_path);
  my($parent_path, @files);

  $parent_path = $url_path ? $self->_tree_path(dirname $url_path) : '';
  $parent_path =~ s!\.$!!;

  $self->stash(
    files => \@files,
    name => basename($url_path),
    parent_path => $parent_path,
    url_path => $self->_tree_path($url_path),
  );

  $self->_loop_files($disk_path, sub {
    my($file, $ext, $type) = @_;
    $type =~ m!^(image|directory)! and push @files, {
      basename => Mojo::Util::decode('UTF-8', $file),
      id => $file =~ s/\W/_/gr, # / st2 hack
      size => -s "$disk_path/$file",
      src => $self->_thumb_path($url_path, $file),
      type => $type,
      url => $type eq 'directory' ? $self->_tree_path($url_path, $file) : $self->_show_path($url_path, $file),
    };
  });

  $self->render(template => 'files/gallery');
}

=head2 raw

Will serve a file in raw format.

=cut

sub raw {
  my $self = shift;
  my $url_path = $self->_url_path;
  my($ext, $type) = $self->_extract_extension_and_filetype($self->_root_path, $url_path);

  if($type !~ m!^image! or $self->param('download')) {
    return $self->SUPER::raw;
  }

  my $exif = Image::EXIF->new(join '/', $self->_root_path, $url_path);
  my $inline = $self->param('inline') ? 1024 : '';
  my $orientation = $exif->get_image_info->{'Image Orientation'} || '';
  my $static;

  given($orientation) {
    when(/^.*left.*bottom/i)  { $orientation = 3 }
    when(/^.*bottom.*right/i) { $orientation = 2 }
    when(/^.*right.*top/i)    { $orientation = 1 }
    default                   { $orientation = 0 }
  }

  if($orientation or $inline) {
    eval {
      my $path = $self->app->config->{Files}{thumb_path};
      my $md5 = Mojo::Util::md5_sum($url_path);
      $md5 .= "_$inline" if $inline;
      unless(-e "$path/$md5") {
        my $t = Image::Imlib2->load(join '/', $self->_root_path, $url_path);
        $t->image_orientate($orientation);
        $t = $t->create_scaled_image($inline, 0) if $inline;
        $t->image_set_format('jpeg');
        $t->save("$path/$md5");
      }
      $static = Mojolicious::Static->new(paths => [$path]);
      $url_path = $md5;
    } or do {
      $self->app->log->error("[Imlib2] $@");
    };
  }

  $self->res->headers->content_type($type);
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
  my $md5 = Mojo::Util::md5_sum($url_path) .'_120.jpg';
  my $thumb = join '/', $static->paths->[0], $md5;

  unless(-e $thumb) {
    eval {
      my $t = Image::Imlib2->load(join '/', $self->_root_path, $url_path);
      $t->image_set_format('jpeg');
      $t->create_scaled_image(120, 120)->save($thumb);
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

sub _root_path { join '/', shift->app->config->{Files}{private_path}, grep { length } @_ }
sub _thumb_path { shift; join '/', '/gallery/thumb', grep { length } @_ }
sub _tree_path { shift; join '/', '/gallery', grep { length } @_ }

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
