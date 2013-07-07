package Batware::Shotwell;

=head1 NAME

Batware::Shotwell - View photos from Shotwell database

=cut

use Mojo::Base 'Batware::Gallery';
use File::Basename;
use DBI;

=head1 ATTRIBUTES

=head2 dbh

Creates a L<DBI> object with the the Shotwell database as source. The location
to the database is found in the config by looking for "/Shotwell/dbname".

=cut

has dbh => sub {
  my $self = shift;
  my $dbname = $self->app->config->{Shotwell}{dbname};

  DBI->connect("dbi:SQLite:dbname=$dbname");
};

=head1 METHODS

=head2 events

List events from Shotwell database.

=cut

sub events {
  my $self = shift;
  my($sth, @files);

  $sth = $self->dbh->prepare(<<'  SQL');
    SELECT id, name, time_created
    FROM EventTable
    WHERE name <> ''
    ORDER BY time_created DESC
  SQL
  $sth->execute;

  while(my $row = $sth->fetchrow_hashref('NAME_lc')) {
    push @files, {
      basename => Mojo::Util::decode('UTF-8', $row->{name}),
      date => scalar(localtime $row->{time_created}),
      id => $row->{id},
      url => $self->_tree_path($row->{id}, $row->{name}),
    };
  }

  $self->stash(
    files => \@files,
    name => 'Events',
    parent_path => $self->_tree_path,
  );
}

=head2 tree

List image files by event name.

=cut

sub tree {
  my $self = shift;
  my $event_id = $self->stash('event_id');
  my($sth, @files);

  $sth = $self->dbh->prepare(<<'  SQL');
    SELECT id, filename, filesize, title
    FROM PhotoTable
    WHERE event_id = ?
    ORDER BY timestamp
  SQL
  $sth->execute($event_id);

  while(my $row = $sth->fetchrow_hashref('NAME_lc')) {
    my($ext, $type) = $self->_extract_extension_and_filetype($row->{filename});
    push @files, {
      basename => Mojo::Util::decode('UTF-8', $row->{title} || basename $row->{filename}),
      id => $row->{id},
      size => $row->{filesize} || 0,
      src => $self->_thumb_path($row->{id}),
      type => $type || 'image/unknown',
      url => $self->_show_path($row->{id}),
    };
  }

  $self->stash(
    files => \@files,
    name => $self->stash('event_name') || 'Events',
    parent_path => $event_id ? $self->_tree_path : '',
  );

  $self->render(template => 'files/gallery');
}

=head2 raw

Will set "url_path" in stash before calling L<Batware::Gallery/raw>.

=cut

sub raw {
  my $self = shift;
  $self->_set_url_path or return $self->render_not_found;
  $self->SUPER::raw;
}

=head2 show

Will set "url_path" in stash before calling L<Batware::Gallery/show>.

=cut

sub show {
  my $self = shift;
  $self->_set_url_path or return $self->render_not_found;
  $self->SUPER::show;
}

=head2 thumb

Will set "url_path" in stash before calling L<Batware::Gallery/thumb>.

=cut

sub thumb {
  my $self = shift;
  $self->_set_url_path or return $self->render_not_found;
  $self->SUPER::thumb;
}

sub _set_url_path {
  my $self = shift;
  my($sth, $row);

  $sth = $self->dbh->prepare(<<'  SQL');
    SELECT filename
    FROM PhotoTable
    WHERE id = ?
  SQL

  $sth->execute($self->stash('photo_id'));
  $row = $sth->fetchrow_hashref || {};
  $self->stash(url_path => $row->{filename});
  $row->{filename};
}

sub _root_path { '' } # url_path contains complete path
sub _tree_path { shift; join '/', '/shotwell', grep { length } @_ }
sub _show_path { shift; join '/', '/shotwell/show', grep { length } @_ }
sub _thumb_path { shift; join '/', '/shotwell/thumb', grep { length } @_ }

=head1 DATABASE SCHEME

=head2 EventTable

  id INTEGER PRIMARY KEY,
  name TEXT,
  primary_photo_id INTEGER,
  time_created INTEGER,primary_source_id TEXT,
  comment TEXT

=head2 PhotoTable

  id INTEGER PRIMARY KEY,
  filename TEXT UNIQUE NOT NULL,
  width INTEGER,
  height INTEGER,
  filesize INTEGER,
  timestamp INTEGER,
  exposure_time INTEGER,
  orientation INTEGER,
  original_orientation INTEGER,
  import_id INTEGER,
  event_id INTEGER,
  transformations TEXT,
  md5 TEXT,
  thumbnail_md5 TEXT,
  exif_md5 TEXT,
  time_created INTEGER,
  flags INTEGER DEFAULT 0,
  rating INTEGER DEFAULT 0,
  file_format INTEGER DEFAULT 0,
  title TEXT,
  backlinks TEXT,
  time_reimported INTEGER,
  editable_id INTEGER DEFAULT -1,
  metadata_dirty INTEGER DEFAULT 0,
  developer TEXT,
  develop_shotwell_id INTEGER DEFAULT -1,
  develop_camera_id INTEGER DEFAULT -1,
  develop_embedded_id INTEGER DEFAULT -1,
  comment TEXT

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;