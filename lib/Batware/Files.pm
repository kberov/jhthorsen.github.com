package Batware::Files;

=head1 NAME

Batware::Files - Browse files

=cut

use feature 'switch';
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util 'slurp';
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
  my($parent_path, @files);

  $parent_path = $url_path ? $self->_tree_path(dirname $url_path) : '';
  $parent_path =~ s!\.$!!;

  $self->stash(
    files => \@files,
    parent_path => $parent_path,
    url_path => $self->_tree_path($url_path),
    README => '',
  );

  $self->_loop_files($disk_path, sub {
    my($file, $ext, $type) = @_;
    $self->stash(README => slurp "$disk_path/$file") if $file eq 'README';
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

=head2 show

Will show a single file embedded in a template.

=cut

sub show {
  my $self = shift;
  my $url_path = $self->_url_path;
  my $disk_path = $self->_root_path($url_path);
  my($ext, $type) = $self->_extract_extension_and_filetype($disk_path);

  return $self->tree unless $type =~ m!/!;

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
  my $static = Mojolicious::Static->new(paths => [$self->_root_path]);
  my($ext, $type) = $self->_extract_extension_and_filetype($self->_root_path, $url_path);

  return $self->tree unless $type =~ m!/!;
  $self->res->headers->content_type($type);
  $self->res->headers->content_disposition(qq(attachment; filename="@{[basename $url_path ]}")) if $self->param('download');
  $static->serve($self, $url_path) or return $self->render(text => 'Unable to serve file', format => 'txt');
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

  if(my $link = readlink $path) {
    $path = $link;
  }

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
  my @files;

  opendir my $DH, $disk_path or return $self->reply->not_found;

  @files = sort {
                 $a->[1] <=> $b->[1]
              || $a->[0] cmp $b->[0]
           } map {
              [$_, ! -d "$disk_path/$_" ];
           } readdir $DH;

  for(@files) {
    my $file = $_->[0];
    next if $file =~ /^\./;
    next if !-r "$disk_path/$file";
    $cb->($file, $self->_extract_extension_and_filetype($disk_path, $file));
  }
}

sub _url_path {
  my $self = shift;
  my $url_path = $self->stash('url_path');

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
