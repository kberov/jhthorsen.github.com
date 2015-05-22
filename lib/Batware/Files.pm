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

=head2 detect

Calls L</tree>, L</show> or L</raw> based on request.

=cut

sub detect {
  my $self = shift;
  my $url_path = $self->_url_path;

  return $self->raw if $self->param('raw') or $self->param('download');
  return $self->tree if -d $self->_root_path($url_path);
  return $self->show;
}

=head2 tree

Will show a list of files.

=cut

sub tree {
  my $self = shift;
  my $url_path = $self->_url_path;
  my $disk_path = $self->_root_path($url_path);
  my @files;

  $self->stash(files => \@files, template => 'files/tree', README => '');

  $self->_loop_files($disk_path, sub {
    my($file, $ext, $type) = @_;

    if ($file eq 'index.html') {
      delete $self->{url_path};
      return $self->stash(url_path => $self->_url_path($file))->raw;
    }
    if ($file eq 'README') {
      $self->stash(README => slurp "$disk_path/$file");
    }

    push @files, {
      basename => Mojo::Util::decode('UTF-8', $file),
      shortname => 15 <= length $file ? substr($file, 0, 12) .'...' : $file,
      size => -s "$disk_path/$file",
      ext => $ext,
      type => $type,
      url_path => $self->_url_path($file),
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
  );

  return $self->render(template => 'files/include') if $type eq 'text/include';
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
  my $filename = basename $url_path;
  my $static = Mojolicious::Static->new(paths => [$self->_root_path]);
  my $headers = $self->res->headers;
  my($ext, $type) = $self->_extract_extension_and_filetype($self->_root_path, $url_path);

  return $self->tree unless $type =~ m!/!;
  $type = "$type;charset=UTF-8" if $type =~ /^text/;
  $headers->content_type($type);
  $headers->content_disposition(qq(attachment; filename="$filename")) if $self->param('download') or $self->stash('download');
  $static->serve($self, $url_path) or return $self->render(text => 'Unable to serve file', format => 'txt');
  $self->rendered;
}

sub _root_path { join '/', shift->app->config->{Files}{public_path}, grep { length } @_ }

sub _extract_extension_and_filetype {
  my $self = shift,
  my $path = join '/', @_;
  my($ext, $type);

  if(my $link = readlink $path) {
    $path = $link;
  }

  return('', 'directory') if -d $path;

  $ext = lc(($path =~ m!\.(\w+)$!)[0] || '');
  $type = +(grep { $ext eq $_ } qw( ep pm pl PL sh t )) ? 'text/plain'
        : $ext eq 'js' ? 'text/javascript'
        : $ext eq 'tt' ? 'text/include'
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

  return $self;
}

sub _url_path {
  my ($self, $file) = @_;

  if ($file) {
    my $url_path = $self->_url_path;
    $url_path =~ s!^\.!!; # private
    return length $url_path ? "$url_path/$file" : $file;
  }
  elsif ($self->{url_path}) {
    return $self->{url_path};
  }
  else {
    my $url_path = $self->stash('url_path');

    $url_path =~ s!^/!!;
    $url_path =~ s!/$!!;
    $url_path =~ s!//!/!g;
    $url_path =~ s!\.\.!!g;

    $self->stash(url_path => $url_path);

    return $self->{url_path} = $self->stash('route_prefix') eq 'private' ? ".$url_path" : $url_path;
  }
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
