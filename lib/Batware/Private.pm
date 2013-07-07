package Batware::Private;

=head1 NAME

Batware::Private - Browse files, but not folders

=cut

use Mojo::Base 'Batware::Files';

=head1 METHODS

=head2 login

Used to enable login to protected resources.

=cut

sub login {
  my $self = shift->render_later;
  my $username = $self->param('username') || '';
  my $password = $self->param('password') || '';

  $self->req->method eq 'POST' or return $self->render;
  $self->redis->hgetall("username:$username", sub {
    my($redis, $user) = @_;

    if($user->{password} and $user->{password} eq crypt $password, $user->{password}) {
      $self->session(username => $username);
      $self->redirect_to($self->param('url') || 'login');
    }
    else {
      $self->render;
    }
  });
}

=head2 tree

Will show a list of files.

=cut

sub tree {
  my $self = shift;
  my $url_path = $self->_url_path;
  my $disk_path = $self->_root_path($url_path);

  return $self->render_not_found unless length $url_path > 12;
  return $self->render_not_found unless -d $disk_path;

  if($self->req->method eq 'POST') {
    my @files = $self->req->upload('file');
    $self->app->log->info("files=@files");
    $_->move_to("$disk_path/" .$_->filename) for grep { $_->filename } @files;
  }

  $self->SUPER::tree;
  $self->render(
    template => 'files/tree',
    show_upload => -e "$disk_path/.upload",
  );
}

sub _root_path { join '/', shift->app->config->{Files}{private_path}, grep { length } @_ }
sub _raw_path { shift; join '/', '/private/raw', grep { length } @_ }
sub _show_path { shift; join '/', '/private/show', grep { length } @_ }
sub _tree_path { shift; join '/', '/private/tree', grep { length } @_ }
sub _thumb_path { shift; join '/', '/private/thumb', grep { length } @_ }

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
