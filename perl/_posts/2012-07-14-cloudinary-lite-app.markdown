---
layout: post
title: "A #Mojolicious lite app that use @Cloudinary"
tag: perl
category: Programming
---

So earlier this week I've written about 
[How to deliver your images through Cloudinary with Perl](/perl/2012-07-10-cloudinary-how-to-deliver-your-static-images)
and [Cloudinary examples for applying effects to your images](/perl/2012-07-11-cloudinary-effects).
Today I'm posting a Mojolicious lite app which can upload images to your
Cloudinary account, show them on a web page and allow the visitor to
delete them.

The example use javascript to load the images, which can be useful if you
want to load one version on a small device and another one on a desktop
computer.

Note: The __persistent_storage__ in the lite app is NOT how you should do it.
You should store the public IDs in some sort of local database
([PostgreSQL](http://www.postgresql.org), [MongoDB](http://www.mongodb.org), ...)
to make the data persistent.

Note: Allowing anybody to delete your Cloudinary assets is a bad idea, but
let's keep it simple for the sake of the example app.

Note: This application does not work, since the __api_key__ / __api_secret__
is not valid for the __cloud_name__ "demo".

## Resources

* [Cloudinary's jQuery plugin](http://cloudinary.com/blog/cloudinary_s_jquery_library_for_embedding_and_transforming_images)
* [Cloudinary perl module](http://metacpan.org/module/Cloudinary)
* [Mojolicious::Lite perl module](http://metacpan.org/module/Mojolicious::Lite)

## Mojolicious lite app example

    use Mojolicious::Lite;

    # your params can be found at https://cloudinary.com/console
    plugin cloudinary => {
        api_key => '1234567890',
        api_secret => 'your-super-s3cret',
        cloud_name => 'demo', # your cloud name
    };

    # this need to be some sort of backend database
    my $persistent_storage = { horses => time };

    get '/' => 'index';

    post '/image' => sub {
        my $self = shift;

        $self->render_later;
        $self->cloudinary_upload({
            file => scalar $self->req->upload('some_file_field'),
            on_success => sub {
                my($res, $tx) = @_;
                $self->stash(message => 'The image was uploaded');
                $self->app->persistent_storage->{$res->{'public_id'}} = time;
                $self->render(template => 'index');
            },
            on_error => sub {
                my($res, $tx) = @_;
                $self->stash(message =>
                    $res ? $res->{'error'}{'message'}
                        : 'Could not upload the image');
                $self->render(template => 'index');
            },
        });
    };

    get '/image/:public_id/delete' => sub {
        my $self = shift;
        my $id = $self->param('public_id');

        $self->render_later;
        $self->cloudinary_destroy({
            public_id => $id,
            on_success => sub {
                $self->stash(message => 'The image was destroy');
                delete $self->app->persistent_storage->{$id};
                $self->render(template => 'index');
            },
            on_error => sub {
                my($res, $tx) = @_;
                $self->stash(message =>
                    $res ? $res->{'error'}{'message'}
                        : 'Could not destroy the image');
                $self->render(template => 'index');
            },
        });
    };

    app->defaults(cloud_name => 'demo', message => '', images => $persistent_storage);
    app->secret('yey!');
    app->start;

    __DATA__
    @@ layouts/default.html.ep
    <!DOCTYPE html>
    <html>
    <head><title><%= title %></title></head>
    %= javascript '/js/jquery.js'
    %= javascript 'https://raw.github.com/cloudinary/cloudinary_js/master/js/jquery.cloudinary.js';
    %= javascript begin
    $(document).ready(function() {
        $.cloudinary.config('cloud_name', '<%= $cloud_name %>');
        $('img[data-src]').cloudinary();
    });
    % end
    <body><%= content %></body>
    </html>

    @@ index.html.ep
    % layout 'default';
    % title 'Upload image example';

    % if($message) {
    <p><%= $message %></p>
    % }

    %= form_for '/image', method => 'post', enctype => 'multipart/form-data', begin
        <div>
            <label>Image</label>
            %= file_field 'some_file_field';
            %= submit_button 'Upload';
        <div>
    % end

    % for my $id (keys %$images) {
    <p>
        %= $id
        %= cloudinary_js_image "$id.jpg", { width => 300 };
        %= link_to "Delete $id", 'imagepublic_iddelete', { public_id => $id };
    <p>
    % }

<!--
grep "^\(    \|$\)" perl/_posts/2012-07-15-cloudinary-lite-app.markdown | sed 's#    ##' | perl - daemon
-->
