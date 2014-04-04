package Mojolicious::Plugin::Shotwell;

=head1 NAME

Mojolicious::Plugin::Shotwell - View photos from Shotwell database

=head1 VERSION

0.0405

=head1 SYNOPSIS

  use Mojolicious::Lite;

  # allow /shotwell/... resources to be protected by login
  my $protected = under '/shotwell' => sub {
    my $c = shift;
    return 1 if $c->session('username') or $c->shotwell_access_granted;
    $c->render('login');
    return 0;
  };

  plugin shotwell => {
    dbname => '/home/username/.local/share/shotwell/data/photo.db',
    routes => {
      default => $protected,
      permalink => app->routes->get('/:permalink'), # not protected
    }
  };

  app->start;

This module can also be tested from command line if you have the defaults set
up:

  $ perl -Mojo -e'plugin "shotwell"; app->start' daemon

=head1 DESCRIPTION

This plugin provides actions which can render data from a
L<Shotwell|http://www.yorba.org/projects/shotwell> database:

=over 4

=item * Events

See L</events> and L</event>.

=item * Tags

See L</tags> and L</tag>.

=item * Thumbnails

See L</thumb>.

=item * Photos

See L</show> and L</raw>.

=back

=cut

use feature 'state';
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Loader;
use Mojo::Util qw( decode md5_sum );
use Carp ();
use DBI;
use File::Basename qw( basename dirname );
use File::Spec::Functions qw( catdir );
use Imager;

use constant DEBUG => $ENV{MOJO_SHOTWELL_DEBUG} ? 1 : 0;
use constant DEFAULT_DBI_ATTRS => { RaiseError => 1, PrintError => 0, AutoCommit => 1 };
use constant SHOTWELL_PERMALINK => 'spl';
use constant SPECIAL_BASENAME => md5_sum(time .$$ .rand 9999999);

our $VERSION = '0.0405';

my @HELPERS = qw(
  access_granted
  events
  photos_by
);

# from Imager::ExifOrientation
my $ROTATE_MAP = {
  1 => { right => 0,   mirror => 0    }, # Horizontal (normal)
  2 => { right => 0,   mirror => 'h'  }, # Mirror horizontal
  3 => { right => 0,   mirror => 'hv' }, # Rotate 180 (rotate is too noisy)
  4 => { right => 0,   mirror => 'v'  }, # Mirror vertical
  5 => { right => 270, mirror => 'h'  }, # Mirror horizontal and rotate 270 CW
  6 => { right => 90,  mirror => 0    }, # Rotate 90 CW
  7 => { right => 90,  mirror => 'h'  }, # Mirror horizontal and rotate 90 CW
  8 => { right => 270, mirror => 0    }, # Rotate 270 CW
};

sub _DUMP {
  my($format, $arg) = @_;
  require Data::Dumper;
  local $Data::Dumper::Indent = 0;
  local $Data::Dumper::Sortkeys = 1;
  local $Data::Dumper::Terse = 1;
  printf STDERR "[SHOTWELL] $format\n", Data::Dumper::Dumper($arg);
}

=head1 ATTRIBUTES

=head2 cache_dir

Path to where all the scaled/rotated images gets stored. Defaults to
"mojolicious-plugin-shotwell-cache" in the system temp directory.
This can be overridden in L</register>:

  $self->register($app, { cache_dir => '/some/path' });

=cut

has cache_dir => sub {
  return '/tmp/mojolicious-plugin-shotwell-cache';
};

=head2 dsn

Returns argument for L<DBI/connect>. Default is

  dbi:SQLite:dbname=$HOME/.local/share/shotwell/data/photo.db

C<$HOME> is the C<HOME> environment variable. The default dsn can be
overridden by either giving "dsn" or "dbname" to L</register>. Example:

  $self->register($app, { dbname => $path_to_db_file });

=cut

has dsn => sub {
  my $home = $ENV{HOME} || '';
  "dbi:SQLite:dbname=$home/.local/share/shotwell/data/photo.db";
};

=head2 sizes

This will be deprecated.

=cut

has sizes => sub {
  +{
    inline => [ 1024, 0 ],
    thumb => [ 100, 100 ],
  };
};

has _types => sub { Mojolicious::Types->new };
has _log => sub { Mojo::Log->new };

=head1 ACTIONS

=head2 events

Default route: C</>.

Render data from EventTable. Data is rendered as JSON or defaults to a
template by the name "templates/shotwell/events.html.ep".

JSON data:

  [
    {
      id => $int,
      name => $str,
      time_created => $epoch,
      url => $shotwell_event_url,
    },
    ...
  ]

The JSON data is also available in the template as C<$events>.

=cut

sub events {
  my($self, $c) = @_;

  $c->respond_to(
    json => sub { shift->render(json => $self->shotwell_events($c)) },
    any => sub { shift->render(events => $self->shotwell_events($c)); }
  );
}

=head2 event

Default route: C</event/:id/:name>.

Render photos from PhotoTable, by a given event id. Data is rendered as JSON
or defaults to a template by the name "templates/shotwell/event.html.ep".

JSON data:

  [
    {
      id => $int,
      size => $int,
      title => $str,
      raw => $shotwell_raw_url,
      thumb => $shotwell_thumb_url,
      url => $shotwell_show_url,
    },
    ...
  ]

The JSON data is also available in the template as C<$photos>.

=cut

sub event {
  my($self, $c) = @_;
  my $sth = $self->_sth($c, $self->_sql('event'), $c->stash('id'));
  my $row = $sth->fetchrow_hashref or return $c->render_not_found;

  $c->stash(
    id => $row->{id},
    name => decode('UTF-8', $row->{name}),
    time_created => $row->{time_created},
  );

  if($c->param('permalink')) {
    $self->_permalink_create($c, collection => $self->_event_to_photo_ids($c));
  }
  else {
    $self->_photos($c, event_id => $c->stash('id'));
  }
}

sub _event_to_photo_ids {
  my($self, $c) = @_;
  my $sth = $self->_sth($c, $self->_sql('photos_by_event_id'), $c->stash('id'));
  my $ids = [];

  while(my $photo = $sth->fetchrow_hashref('NAME_lc')) {
    push @$ids, $photo->{id};
  }

  return $ids;
}

=head2 permalink

Default route: C</:permalink>.

Will either render the same as L</show> or L</event>, dependent on the
type of permalink.

=cut

sub permalink {
  my($self, $c) = @_;
  my $sth = $self->_sth($c, $self->_sql('permalink'), $c->stash('permalink'));
  my $row = $sth->fetchrow_hashref or return $c->render_not_found;
  my @ids = split /,/, $row->{foreign_ids};

  # store it for shotwell_access_granted() helper usage
  $c->session(SHOTWELL_PERMALINK, $c->stash('permalink'));

  if($row->{type} eq 'collection') {
    warn "[SHOTWELL] render collection from permalink\n" if DEBUG;
    $c->stash(
      comment => $row->{comment},
      template => 'shotwell/event',
      foreign_ids => \@ids,
    );
    $self->_photos($c, ids => @ids);
  }
  else {
    warn "[SHOTWELL] render single image from permalink\n" if DEBUG;
    $c->stash(
      id => $ids[0],
      basename => SPECIAL_BASENAME,
      comment => $row->{comment},
      foreign_ids => \@ids,
      template => 'shotwell/show',
    );
    $self->show($c);
  }
}

=head2 permalink_delete

Default route: C</:permalink/delete>.

Used to delete a permalink from backend.

=cut

sub permalink_delete {
  my($self, $c) = @_;
  my $sth = $self->_sth($c, $self->_sql('permalink_delete'), $c->stash('permalink'));

  if($sth->rows) {
    delete $c->session->{SHOTWELL_PERMALINK()};
    $c->respond_to(
      json => sub { shift->render(json => {}) },
      any => sub { shift->render },
    );
  }
  else {
    $c->render_not_found;
  }
}

=head2 tags

Default route: C</tags>.

Render data from TagTable. Data is rendered as JSON or defaults to a template
by the name "templates/shotwell/tags.html.ep".

JSON data:

  [
    {
      name => $str,
      url => $shotwell_tag_url,
    },
    ...
  ]

The JSON data is also available in the template as C<$tags>.

=cut

sub tags {
  my($self, $c) = @_;
  my $sth = $self->_sth($c, $self->_sql('tags'));
  my @tags;

  while(my $tag = $sth->fetchrow_hashref) {
    my $name = decode('UTF-8', $tag->{name});
    push @tags, {
      name => $name,
      url => $c->url_for('shotwell/tag' => name => $name, format => $c->stash('format')),
    };
  }

  $c->respond_to(
    json => sub { shift->render(json => \@tags) },
    any => sub { shift->render(tags => \@tags) },
  );
}

=head2 tag

Default route: C</tag/:name>.

Render photos from PhotoTable, by a given tag name. Data is rendered as JSON
or defaults to a template by the name "templates/shotwell/tag.html.ep".

The JSON data is the same as for L</event>.

=cut

sub tag {
  my($self, $c) = @_;
  my $sth = $self->_sth($c, $self->_sql('photo_id_list_by_tag_name'), $c->stash('name'));
  my $row = $sth->fetchrow_hashref or return $c->render_not_found;
  my @ids = map { s/thumb0*//; hex } grep { /^thumb/ } split /,/, $row->{photo_id_list} || '';

  if($c->param('permalink')) {
    $self->_permalink_create($c, collection => \@ids);
  }
  else {
    $self->_photos($c, ids => @ids);
  }
}

=head2 raw

Default route: C</raw/:id/*basename>.

Render raw photo.

Example usage

  http://domain.com/raw/42/image.jpg
  http://domain.com/raw/42/image.jpg?download=1
  http://domain.com/raw/42/image.jpg?size=1024x
  http://domain.com/raw/42/image.jpg?size=1024x768
  http://domain.com/raw/42/image.jpg?size=x1024&quality=normal
  http://domain.com/raw/42/image.jpg?inline=1 # will be depraceted

=cut

sub raw {
  my($self, $c) = @_;
  my $photo = $self->_photo($c) or return;
  my $file = $photo->{filename};
  my $static;

  if($c->param('download')) {
    my $basename = basename $file;
    $c->res->headers->content_disposition(qq(attachment; filename="$basename"));
  }
  if(my $size = $c->param('size')) {
    my $quality = $c->param('quality') || 'normal';
    $file = $self->_scale_photo($photo, $quality, split /x/, $size);
  }
  if($c->param('inline')) {
    $file = $self->_scale_photo($photo, normal => @{ $self->sizes->{inline} });
  }

  $static = Mojolicious::Static->new(paths => [dirname $file]);

  return $c->rendered if $static->serve($c, basename $file);
  return $c->render_exception("Unable to serve ($file)");
}

=head2 show

Default route: C</show/:id/*basename>.

Render a template with an photo inside. The name of the template is
"templates/shotwell/show.html.ep".

The stash data is the same as one element described for L</event> JSON data.

=cut

sub show {
  my($self, $c, $skip_permalink) = @_;
  my $photo = $self->_photo($c) or return;

  if(!$c->stash('foreign_ids') and $c->param('permalink')) {
    return $self->_permalink_create($c, single => [$photo->{id}]);
  }

  $c->render(
    size => $photo->{filesize} || 0,
    title => decode('UTF-8', $photo->{title} || $c->stash('basename')),
    raw => $c->url_for('shotwell/raw', %$photo),
    thumb => $c->url_for('shotwell/thumb', %$photo),
    url => $c->url_for('shotwell/show', %$photo),
  );
}

=head2 thumb

Default route: C</thumb/:id/*basename>.

Render photo as a thumbnail.

=cut

sub thumb {
  my($self, $c) = @_;
  my $photo = $self->_photo($c) or return;
  my $file = $self->_scale_photo($photo, preview => @{ $self->sizes->{thumb} });
  my $static = Mojolicious::Static->new(paths => [dirname $file]);

  return $c->rendered if $static->serve($c, basename $file);
  return $c->render_exception("Unable to serve ($file)");
}

sub _permalink_create {
  my($self, $c, $type, $ids) = @_;
  my $sth = $self->_sth($c, $self->_sql('permalink_create'), { execute => 0 });
  my $comment = $c->tx->remote_address || '';
  my $time = time;
  my $permalink;

  $ids = join ',', @$ids;

  do {
    $permalink = substr md5_sum($time. $$. rand 99999), 2, 15; # 2 and 15 is not chosen for any special reason
    eval { $sth->execute($time, $permalink, $type, $ids, $comment) };
  } while($@);

  $c->session(SHOTWELL_PERMALINK, $permalink);
  $c->redirect_to('shotwell/permalink', permalink => $permalink);
}

sub _photo {
  my($self, $c) = @_;
  my $sth = $self->_sth($c, $self->_sql('photo_by_id'), $c->stash('id'));
  my $photo = $sth->fetchrow_hashref;
  my $basename;

  if(!$photo) {
    warn "[SHOTWELL] Could not find photo by id\n" if DEBUG;
    $c->render_not_found;
    return;
  }

  $photo->{filename} ||= '';
  $basename = basename $photo->{filename};

  if($c->stash('basename') ne $basename and $c->stash('basename') ne SPECIAL_BASENAME) {
    _DUMP 'photo=%s', $photo if DEBUG;
    $c->render_exception("Invalid basename: $basename");
    return;
  }

  $c->stash(basename => $basename);
  $photo->{basename} = $basename;
  $photo;
}

sub _photos {
  my($self, $c, @args) = @_;

  $c->respond_to(
    json => sub { shift->render(json => $self->shotwell_photos_by($c, @args)) },
    any => sub { shift->render(photos => $self->shotwell_photos_by($c, @args)) },
  );
}

sub _scale_photo {
  my($self, $photo, $quality, @xy) = @_;
  my $out = sprintf '%s/%s-%sx%s', $self->cache_dir, md5_sum($photo->{filename}), map { $xy[$_] ||= 0 } 0..1;
  my $t0;

  return $out if -s $out;
  use Time::HiRes qw( gettimeofday tv_interval );
  $t0 = [gettimeofday] if DEBUG;

  eval {
    my $image = Imager->try(new => file => $photo->{filename});
    my $orientation = $image->tags(name => 'exif_orientation') || 1;
    my $rotate = $ROTATE_MAP->{$orientation};

    $image = $image->try(flip => dir => $rotate->{mirror}) if $rotate->{mirror};
    $image = $image->try(rotate => right => $rotate->{right}) if $rotate->{right};
    $image = $image->try(scale => xpixels => $xy[0], ypixels => $xy[1], type => 'nonprop', qtype => $quality);
    $image->try(write => file => $out, type => 'jpeg');
    printf STDERR "[SHOTWELL] Imager %s %ss\n", $out, tv_interval $t0;
    1;
  } or do {
    $self->_log->error("[Imager] $@");
    $out = $photo->{filename};
  };

  return $out;
}

sub Imager::try {
  my($image, $method, @args) = @_;
  warn "Imager->$method(@args)\n" if DEBUG;
  $image->$method(@args) || die "Imager->$method(...) FAIL ", $image->errstr;
}

=head1 HELPERS

=head2 shotwell_access_granted

  $bool = $c->shotwell_access_granted;

Returns true if the L<session|Mojolicious::Controller/session> contains a
valid permalink id.

=cut

sub shotwell_access_granted {
  my($self, $c) = @_;
  my $permalink = $c->session(SHOTWELL_PERMALINK) or return 0;
  my $sth = $self->_sth($c, $self->_sql('permalink'), $permalink);
  my $row = $sth->fetchrow_hashref or return 0;

  if($c->req->url =~ m!/(\d+)/!) { # TODO: This is one ugly hack :(
    my $id = $1;
    return $row->{foreign_ids} =~ /\b$id\b/ ? 1 : 0;
  }
  else {
    return 1;
  }
}

=head2 shotwell_events

  $array_ref = $c->shotwell_events;

Returns a list of events:

  [
    {
      id => $int,
      name => $str,
      time_created => $epoch,
      url => $str,
    },
    # ...
  ];

=cut

sub shotwell_events {
  my($self, $c) = @_;
  my $sth = $self->_sth($c, $self->_sql('events'));
  my @events;

  while(my $event = $sth->fetchrow_hashref('NAME_lc')) {
    (my $name = $event->{name}) =~ s/\W//g; # /
    push @events, {
      id => int $event->{id},
      name => decode('UTF-8', $event->{name}),
      time_created => $event->{time_created},
      url => $c->url_for(
              'shotwell/event' => (
                id => $event->{id},
                format => $c->stash('format'),
                name => $name,
              )
             ),
    };
  }

  return \@events;
}

=head2 shotwell_photos_by

  $array_ref = $c->shotwell_photos_by(event_id => $id);
  $array_ref = $c->shotwell_photos_by(ids => @id);

=cut

sub shotwell_photos_by {
  my($self, $c, $template, @args) = @_;
  my $sth = $self->_sth($c, $self->_sql("photos_by_$template", @args), @args);
  my @photos;

  while(my $photo = $sth->fetchrow_hashref('NAME_lc')) {
    $photo->{basename} = basename $photo->{filename};
    push @photos, {
      id => int $photo->{id},
      size => int $photo->{filesize} || 0,
      title => decode('UTF-8', $photo->{title} || $photo->{basename}),
      raw => $c->url_for('shotwell/raw' => %$photo),
      thumb => $c->url_for('shotwell/thumb' => %$photo),
      url => $c->url_for('shotwell/show' => %$photo),
    };
  }

  return \@photos;
}

=head1 METHODS

=head2 register

  $self->register($app, \%config);

Set L</ATTRIBUTES> and register L</ACTIONS> in the L<Mojolicious> application.

=cut

sub register {
  my($self, $app, $config) = @_;
  my $helpers = $config->{helpers} || {};
  my $sizes = $self->sizes;

  $self->_log($app->log);
  $self->_types($app->types);
  $self->dsn("dbi:SQLite:dbname=$config->{dbname}") if $config->{dbname};

  for my $name (@HELPERS) {
    my $method = "shotwell_$name";
    $app->helper($helpers->{$name} || $method, sub { $self->$method(@_) });
  }

  unless($config->{skip_bundled_templates}) {
    push @{ $app->renderer->paths }, catdir dirname(__FILE__), 'Shotwell', 'templates';
  }

  for my $k (qw( dsn cache_dir )) {
    $self->$k($config->{$k}) if $config->{$k};
  }
  for my $k (keys %$sizes) {
    $sizes->{$k} = $config->{sizes}{$k} if $config->{sizes}{$k};
  }

  if(!-d $self->cache_dir) {
    mkdir $self->cache_dir or die "[SHOTWELL] mkdir cache_dir(): $!";
  }
  if($config->{paths}) {
    warn "/config/paths is replaced by /config/routes !!!";
    $config->{routes} = delete $config->{paths}; # backward compat
  }
  if($config->{route}) {
    warn "/config/route is replaced by /config/routes/default !!!";
    $config->{routes}{default} = delete $config->{route}; # backward compat
  }

  $self->dsn([ $self->dsn, '', '', DEFAULT_DBI_ATTRS ]) unless ref $self->dsn eq 'ARRAY';
  $self->_create_missing_tables;
  $self->_register_routes($app, %{ $config->{routes} || {} });
}

sub _create_missing_tables {
  my $self = shift;
  my $dbh = DBI->connect(@{ $self->dsn });

  # create "permalinks" table unless it already exists
  eval {
    $dbh->prepare('SELECT COUNT(*) FROM mojolicious_plugin_shotwell_permalinks');
  } or do {
    warn $@ if DEBUG;
    $dbh->prepare($self->_sql('create_permalink_table'))->execute;
    $dbh->prepare($self->_sql('create_permalink_index'))->execute;
  };
}

sub _register_routes {
  my($self, $app, %routes) = @_;

  $routes{default} ||= $app->routes;
  $routes{events} ||= '/';
  $routes{event} ||= '/event/:id/:name';
  $routes{tags} ||= '/tags';
  $routes{tag} ||= '/tag/:name';
  $routes{raw} ||= '/raw/:id/*basename';
  $routes{show} ||= '/show/:id/*basename';
  $routes{thumb} ||= '/thumb/:id/*basename';
  $routes{permalink} ||= '/:permalink';
  $routes{permalink_delete} ||= '/:permalink/delete';

  for my $k (qw( events event tags tag raw show thumb permalink permalink_delete )) {
    warn "[SHOTWELL:ROUTE] $k => $routes{$k}\n" if DEBUG;
    my $route = UNIVERSAL::isa($routes{$k}, 'Mojolicious::Routes::Route') ? $routes{$k} : $routes{default}->get($routes{$k});
    $route->to(cb => sub { $self->$k(@_); })->name("shotwell/$k");
  }
}

sub _sql {
  my($self, $name, @args) = @_;
  my $template;

  state $loader = Mojo::Loader->new;
  state $mt = Mojo::Template->new;

  $template = $loader->data(__PACKAGE__, "$name.sql.ep") or Carp::confess("Could not find template for $name.sql.ep!");
  $mt->render($template, @args);
}

sub _sth {
  my($self, $c, $sst, @bind) = @_;
  my $dbh = $c->stash->{'shotwell.dbh'} ||= DBI->connect(@{ $self->dsn });
  my $sth;

  $sth = $dbh->prepare($sst);

  unless(ref $bind[0]) {
    warn "[SHOTWELL:DBI] $sst(@bind)\n---\n" if DEBUG;
    $sth->execute(@bind);
  }

  $sth;
}

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

=head2 TagTable

  id INTEGER PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  photo_id_list TEXT,
  time_created INTEGER

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;

__DATA__
@@ event.sql.ep
SELECT id, name, time_created FROM EventTable WHERE id = ?

@@ events.sql.ep
SELECT id, name, time_created
FROM EventTable
WHERE name <> ''
ORDER BY time_created DESC

@@ photos_by_event_id.sql.ep
SELECT id, filename, filesize, title
FROM PhotoTable
WHERE event_id = ?
ORDER BY timestamp

@@ tags.sql.ep
SELECT name
FROM TagTable
ORDER BY name

@@ photo_id_list_by_tag_name.sql.ep
SELECT photo_id_list
FROM TagTable
WHERE name = ?

@@ photos_by_ids.sql.ep
% my(@ids) = @_;
SELECT id, filename, filesize, title
FROM PhotoTable
WHERE id IN (<%= join ',', map { '?' } @ids %>)
ORDER BY timestamp

@@ photo_by_id.sql.ep
SELECT id, filename, filesize, title
FROM PhotoTable
WHERE id = ?

@@ permalink.sql.ep
SELECT type, foreign_ids, comment
FROM mojolicious_plugin_shotwell_permalinks
WHERE permalink = ?

@@ permalink_create.sql.ep
INSERT INTO mojolicious_plugin_shotwell_permalinks
(time_created, permalink, type, foreign_ids, comment)
VALUES(?, ?, ?, ?, ?)

@@ permalink_delete.sql.ep
DELETE FROM mojolicious_plugin_shotwell_permalinks
WHERE permalink = ?

@@ create_permalink_table.sql.ep
CREATE TABLE mojolicious_plugin_shotwell_permalinks (
  time_created INTEGER NOT NULL,
  permalink TEXT UNIQUE NOT NULL,
  type TEXT NOT NULL,
  foreign_ids TEXT NOT NULL,
  comment TEXT NOT NULL
)

@@ create_permalink_index.sql.ep
CREATE INDEX permalinks_permalink_index
ON mojolicious_plugin_shotwell_permalinks
(permalink);
