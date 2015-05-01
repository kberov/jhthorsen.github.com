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

=back

=head2 Requirements

It all depends on what you want to do...

=over 4

=item * Batware

L<Mojolicious|http://mojolicio.us> and L<Perl|http://perl.org> are the main
players in this code.

=item * Contact form

L<Mojolicious::Plugin::Mail> is used to send the contact form to my email.

=item * Files

L<File::MimeInfo::Magic> is used to figure out what kind of files we want to
display.

L<Files.pm|https://github.com/jhthorsen/jhthorsen.github.com/blob/batware/lib/Batware/Files.pm>.

=item * DOCSIS service

L<DOCSIS::ConfigFile> and L<Config::General> is used by
L<Docsis.pm|https://github.com/jhthorsen/jhthorsen.github.com/blob/batware/lib/Batware/Docsis.pm>. This is super special
code, which is probably not for general interest.

=back

=head2 Configuration

See L<https://github.com/jhthorsen/jhthorsen.github.com/blob/batware/batware.conf>.

=cut

use Mojo::Base 'Mojolicious';
use File::HomeDir ();
use File::Spec;
use File::Path 'make_path';

our $VERSION = '0.01';

=head1 METHODS

=head2 startup

Called to set up the routes.

=cut

sub startup {
  my $self = shift;
  my $config = $self->_config;
  my $r = $self->routes;

  eval { $self->plugin('Responsinator') };

  $self->plugin(AssetPack => $config->{AssetPack} || {});
  $self->plugin(Mail => $config->{Mail});
  $self->secrets($config->{secrets} || [time.rand.$$]);

  $self->asset('thorsen.css' => qw( /sass/thorsen.scss ));
  $self->asset('thorsen.js' => qw( /js/jquery.min.js /js/jquery.hotkeys.js /js/jquery.touchSwipe.js /js/bat.js ));

  $r->get('/')->to(template => 'index');
  $r->get('/about/cv')->to(template => 'curriculum_vitae');
  $r->get('/contact')->to(template => 'contact', report => '')->name('contact');
  $r->post('/contact')->to(cb => \&_post_contact_form);
  $r->get('/trips')->to(template => 'trips')->name('trips');
  $r->get('/404')->to(template => 'not_found.production');
  $r->get('/500')->to(template => 'exception.production');

  $r->get('/files')->to('files#tree', url_path => '');
  $r->get('/files/tree/(*url_path)')->to('files#tree', url_path => '')->name('files_tree');
  $r->get('/files/show/*url_path')->to('files#show')->name('files_show');
  $r->get('/files/raw/*url_path')->to('files#raw')->name('files_raw');
  $r->get('/files/*url_path')->to('files#redirect');

  $r->get('/service/docsis')->to(cb => sub { $_[0]->redirect_to('docsis') });
  $r->get('/services/docsis')->to(cb => sub { $_[0]->redirect_to('docsis') });
  $r->get('/docsis-editor')->to(template => 'docsis/edit', report => '')->name('docsis');
  $r->get('/docsis-editor/syminfo')->to(template => 'docsis/syminfo')->name('docsis_syminfo');
  $r->post('/docsis-editor')->to('docsis#edit');
  $r->get('/docsis-editor/:id')->to('docsis#load')->name('docsis_load');
}

sub _post_contact_form {
  my $c = shift;

  unless ($c->param('message')) {
    return $c->render(report => 'Message is required.');
  }

  $c->mail(
    to => $c->app->config->{Mail}{receiver},
    from => $c->param('email') || die('Your email is missing.'),
    subject => $c->param('subject') || die('Subject need to be filled out.'),
    template => 'contact',
    format => 'mail',
  );
}

sub _config {
  my $self = shift;
  my $config = $ENV{MOJO_CONFIG} ? $self->plugin('config') : $self->config;
  my $home = File::HomeDir->my_home || $ENV{HOME} || die 'Could not figure out $HOME';
  my $share = File::Spec->catdir($home, qw( .local share batware ));

  $config->{Docsis}{files} ||= File::Spec->catdir($share, 'docsis', 'config');
  $config->{Files}{public_path} ||= File::Spec->catdir($share, 'public');
  $config->{Files}{thumb_path} ||= File::Spec->catdir($share, 'thumbs');

  make_path $_ for (
    $config->{Docsis}{files},
    $config->{Files}{public_path},
    $config->{Files}{thumb_path},
  );

  $config->{Mail}{how} ||= 'smtp';
  $config->{Mail}{howargs} ||= ['smtp.online.no'];
  $config->{Mail}{receiver} ||= 'jhthorsen@cpan.org';
  $config;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
