package Batware;

=head1 NAME

Batware - My personal homepage

=head1 VERSION

0.01

=head1 SYNOPSIS

  $ morbo script/batware
  $ hypnotoad script/batware
  $ ./script/batware daemon

=head1 DESCRIPTION

This is the codebase for L<http://home.thorsen.pm>.

=head2 Features

=over 4

=item * File browser

L<http://home.thorsen.pm/files>.

=item * Pretty print text and code

L<http://home.thorsen.pm/files/show/html/css/style.css>.

=item * Download/share files

=item * Upload files to private (hidden) paths (browse them afterwards)

=item * Display images according to EXIF

L<http://home.thorsen.pm/files/show/skole/transistor/transistor_html_19198ba2.jpg>.

=item * DOCSIS config file editor

L<http://home.thorsen.pm/docsis-editor>.

=item * Shotwell web frontend

L<Shotwell|http://www.yorba.org/projects/shotwell/> is awesome at the desktop,
but what about the web? L<Mojolicious::Plugin::Shotwell> allow the gallery
to be displayed on the web, but the SQLite database seems to be corrupted when
read (?). No worries -
L<Batware.pm|https://github.com/jhthorsen/jhthorsen.github.com/blob/batware/lib/Batware.pm#L253>
has you back.

=back

=head2 Requirements

It all depends on what you want to do...

=over 4

=item * Batware

L<Mojolicious|http://mojolicio.us> and L<Perl|http://perl.org> are the main
players in this code.

=item * Authentication

L<Mojo::Redis> is used by the authentication code in
L<Private.pm|https://github.com/jhthorsen/jhthorsen.github.com/blob/batware/lib/Batware/Private.pm>.

=item * Contact form

L<Mojolicious::Plugin::Mail> is used to send the contact form to my email.

=item * Files

L<File::MimeInfo::Magic> is used to figure out what kind of files we want to
display.

L<Files.pm|https://github.com/jhthorsen/jhthorsen.github.com/blob/batware/lib/Batware/Files.pm>.

=item * Images

L<Image::EXIF> and L<Image::Imlib2> is responsible for rotating and scaling
the images.

Both L<Files.pm|https://github.com/jhthorsen/jhthorsen.github.com/blob/batware/lib/Batware/Files.pm> and
L<Gallery.pm|https://github.com/jhthorsen/jhthorsen.github.com/blob/batware/lib/Batware/Gallery.pm> use these modules.

=item * Shotwell foto gallery

L<DBI> and L<DBD::SQLite> is used by L<Mojolicious::Plugin::Shotwell>.

=item * DOCSIS service

L<DOCSIS::ConfigFile> and L<Config::General> is used by
L<Docsis.pm|https://github.com/jhthorsen/jhthorsen.github.com/blob/batware/lib/Batware/Docsis.pm>. This is super special
code, which is probably not for general interest.

=back

=head2 Configuration

See L<https://github.com/jhthorsen/jhthorsen.github.com/blob/batware/batware.conf>.

=cut

use Mojo::Base 'Mojolicious';
use Mojo::Redis;
use DBI;

our $VERSION = '0.01';

=head1 HELPERS

=head2 eval_code

  $code_return_value = $c->eval_code(CODE);

Used to eval a code ref and set "report" in status on error.

=cut

sub eval_code {
  my($c, $cb) = @_;
  my $res;

  eval {
    $res = $c->$cb;
    1;
  } or do {
    my $e = $@;
    $c->app->log->error($e);
    $e =~ s/ at \S+.*//s;
    $c->stash(report => $e || 'Could not send message!');
  };

  $res;
}

=head2 protected

Returns a route which is protected with login.

=cut

has protected => sub {
  my $self = shift;

  $self->routes->under(sub {
    my $c = shift;
    return 1 if $c->session('username') or $c->shotwell_access_granted;
    $c->render(template => 'private/login');
    return 0;
  });
};

=head2 redis

Returns an instance of L<Mojo::Redis>.

=cut

sub redis {
  my $c = shift;
  $c->stash->{redis} ||= do { Mojo::Redis->new($c->app->config->{Redis}) };
}

=head1 METHODS

=head2 startup

Called to set up the routes.

=cut

sub startup {
  my $self = shift;
  my $config = $self->plugin('config');
  my $r = $self->routes;

  $config->{Shotwell}{routes}{default} = $self->protected->route('/shotwell');
  $config->{Shotwell}{routes}{permalink} = $r->get('/shotwell/:permalink');
  $self->_init_shotwell_database(@{ $config->{Shotwell} }{qw/ sync_from dbname /});

  unless(-d $self->app->config->{Files}{thumb_path}) {
    unless(mkdir $self->app->config->{Files}{thumb_path}) {
      die "Cannot mkdir thumb_path: $self->app->config->{Files}{thumb_path}";
    }
  }

  $self->plugin(AssetPack => $config->{AssetPack} || {});
  $self->plugin(Mail => $config->{Mail});
  $self->plugin(Shotwell => $config->{Shotwell});
  $self->helper(eval_code => \&eval_code);
  $self->helper(redis => \&redis);
  $self->secrets($config->{secrets});

  $self->asset('thorsen.css' => qw( /sass/thorsen.scss ));
  $self->asset('thorsen.js' => qw( /js/jquery.js /js/jquery.hotkeys.js /js/jquery.touchSwipe.js /js/bat.js ));

  $r->get('/')->to(template => 'index');
  $r->get('/about/cv')->to(template => 'curriculum_vitae');
  $r->get('/contact')->to(template => 'contact', report => '')->name('contact');
  $r->post('/contact')->to(cb => \&_post_contact_form);
  $r->get('/trips')->to(template => 'trips')->name('trips');
  $r->get('/404')->to(template => 'not_found.production');
  $r->get('/500')->to(template => 'exception.production');
  $r->any('/login')->to('private#login')->name('login');
  $r->any('/logout')->to(cb => sub { shift->session(expires => 1)->redirect_to('/') })->name('logout');

  $r->get('/files')->to('files#tree', url_path => '');
  $r->get('/files/tree/(*url_path)')->to('files#tree', url_path => '')->name('files_tree');
  $r->get('/files/show/*url_path')->to('files#show')->name('files_show');
  $r->get('/files/raw/*url_path')->to('files#raw')->name('files_raw');
  $r->get('/files/*url_path')->to('files#redirect');

  $r->get('/gallery/show/*url_path')->to('gallery#show')->name('gallery_show');
  $r->get('/gallery/raw/*url_path')->to('gallery#raw')->name('gallery_raw');
  $r->get('/gallery/thumb/*url_path')->to('gallery#thumb')->name('gallery_thumb');
  $r->get('/gallery/*url_path')->to('gallery#tree', url_path => '')->name('gallery_tree');

  $r->any('/private/tree/*url_path')->to('private#tree')->name('private_tree');
  $r->get('/private/show/*url_path')->to('private#show')->name('private_show');
  $r->get('/private/raw/*url_path')->to('private#raw')->name('private_raw');
  $r->any('/private/*url_path')->to('private#tree');

  $r->get('/service/docsis')->to(cb => sub { $_[0]->redirect_to('docsis') });
  $r->get('/services/docsis')->to(cb => sub { $_[0]->redirect_to('docsis') });
  $r->get('/docsis-editor')->to(template => 'docsis/edit', report => '')->name('docsis');
  $r->get('/docsis-editor/syminfo')->to(template => 'docsis/syminfo')->name('docsis_syminfo');
  $r->post('/docsis-editor')->to('docsis#edit');
  $r->get('/docsis-editor/:id')->to('docsis#load')->name('docsis_load');
}

sub _post_contact_form {
  my $c = shift;

  $c->eval_code(sub {
    $c->param('message') or die 'No message?';
    $c->mail(
      to => $c->app->config->{Mail}{receiver},
      from => $c->param('email') || die('Your email is missing.'),
      subject => $c->param('subject') || die('Subject need to be filled out.'),
      template => 'contact',
      format => 'mail',
    );
    $c->stash(report => 'Message was sent!');
  });
}

sub _init_shotwell_database {
  my($self, @args) = @_;

  unless(-e $args[1]) {
    require File::Copy;
    $self->log->info("Creating $args[1]");
    File::Copy::copy(@args);
  }

  unlink "$args[1].lock";
  Mojo::IOLoop->recurring(2, sub { $self->_sync_shotwell_database(@args) });
}

sub _sync_shotwell_database {
  my($self, @args) = @_;
  my @stat = map { (stat $_)[9] || 0 } @args;

  # only one child should do this
  $stat[0] <= $stat[1] and return;
  symlink $args[1], "$args[1].lock" or return;

  my $dbh_from = DBI->connect("dbi:SQLite:dbname=$args[0]", "", "", { RaiseError => 1 });
  my $dbh_to = DBI->connect("dbi:SQLite:dbname=$args[1]", "", "", { RaiseError => 1 });

  $self->log->info("Syncing $args[0] > $args[1]");

  for my $table (qw/ PhotoTable EventTable TagTable /) {
    my $sth_from = $dbh_from->prepare("SELECT * FROM $table");
    my $sth_to;
    my $n = 0;

    $dbh_to->{AutoCommit} = 0;
    $dbh_to->do("DELETE FROM $table");
    $sth_from->execute;

    while(my $row = $sth_from->fetchrow_arrayref) {
      $sth_to ||= do {
        my $q = join ',', map { '?' } @$row;
        $dbh_to->prepare("INSERT INTO $table VALUES ($q)");
      };
      $sth_to->execute(@$row);
      $n++;
    }

    $dbh_to->commit;
    $self->log->info("Synced $n rows from $table")
  }

  unlink "$args[1].lock";
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
