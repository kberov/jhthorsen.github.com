---
layout: post
title: How to deliver your images through Cloudinary with Perl
tag: perl
category: Programming
---

[Cloudinary](http://cloudinary.com) is a cloud-based service for image
management & manipulation. From [their about page](http://cloudinary.com/about):

Use Cloudinary to:
* Manage all your assets and web resources in the cloud.
* Allow any web application, large or small, to enjoy modern web delivery platforms.
* Completely remove the tedious tasks of locally managing web resources; instead, utilize the advanced features and industry best practices we always wished we had.

I personally feel that Cloudinary has lifted a burden from me, since I really
don't like to figure out the best [Perl module](http://metacpan.org) to manipulate
my images. I used to use [Imagemagic](http://imagemagick.org/) for a while, but it
simply isn't that easy to use as Cloudinary.

I started out with the excellent [documentation](http://cloudinary.com/documentation),
discussed with Cloudinary using their online chat, and managed to pull together a
Perl module I named [Cloudinary](https://metacpan.org/module/Cloudinary).
This module is based on top of the  excellent [Mojolicious](http://mojolicio.us) framework,
which allow you to communicate with Cloudinary in an async matter, which can be
useful if you're working with a lot of assets.

## Main features

* [Upload](https://metacpan.org/module/Cloudinary#upload) images and other assets to Cloudinary.
* [Generate URL](https://metacpan.org/module/Cloudinary#url_for) to assets which has been uploaded.
* [Delete](https://metacpan.org/module/Cloudinary#destroy) uploaded assets.

## Example

To run the examples below, you need to install the module first:

    cpanm -n --sudo Cloudinary

Don't have cpanm? Install cpanm using this command:

    curl -L http://cpanmin.us | perl - --self-upgrade

So how do you talk with Cloudinary? Here is an simple example which doesn't even require
an account:

    use feature 'say';
    use Mojo::Base; # or strict and warnings;
    use Cloudinary;

    my $cloudinary = Cloudinary->new(cloud_name => 'demo');
    say $cloudinary->url_for('jhthorsen.jpg' => {
            type => 'facebook',
            width => 50,
            height => 100,
        });

The code above will print this URL, which points to a scaled Facebook image of me:

    http://res.cloudinary.com/demo/image/facebook/h_100,w_50/jhthorsen.jpg

The destribution also includes a [Mojolicious plugin](https://metacpan.org/module/Mojolicious::Plugin::Cloudinary)
which provide helpers which makes embedding images in your
[mojo templates](https://metacpan.org/module/Mojo::Template) easy:

    %= cloudinary_image 'jhthorsen.jpg', { type => 'facebook' };

The above code will produce this output:

<img src="http://res.cloudinary.com/demo/image/facebook/jhthorsen.jpg" alt="jhthorsen.jpg">

## Try it out!

Register a free plan at Cloudinary try it out for your self. My module should
allow you to take advantage of all the cool
[transformations](http://cloudinary.com/documentation/image_transformations)
which Cloudinary provides -- and if not: Create an issue or send me a pull request
on [github](https://github.com/jhthorsen/cloudinary).

More information can be found on metacpan:

* [Cloudinary](https://metacpan.org/module/Cloudinary)
* [Mojolicious::Plugin::Cloudinary](https://metacpan.org/module/Mojolicious::Plugin::Cloudinary)

Enjoy :)
