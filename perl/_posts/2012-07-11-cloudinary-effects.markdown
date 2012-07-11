---
layout: post
title: Cloudinary examples for applying effects to your images
tag: perl
category: Programming
---

So yesterday I [blogged](/perl/2012/07/10/cloudinary-how-to-deliver-your-static-images.html)
about the basic functionality about Cloudinary, but there are so much more
than scaling images that you can do.

__Note__: If you use other programming languages as well, you can read about the same
examples from [Cloudinary's own blog](http://cloudinary.com/blog/cloud_based_api_for_applying_effects_on_images).

__Note__: The examples below is based on the Mojolicious helpers provided from
[Mojolicious::Plugin::Cloudinary](https://metacpan.org/module/Mojolicious::Plugin::Cloudinary),
but you can also use the [Cloudinary](https://metacpan.org/module/Cloudinary) module
directly if you are not inside a mojo template.

## Effects

You can apply a variety of effects to your images using the "effect" argument
to [cloudinary_image()](https://metacpan.org/module/Mojolicious::Plugin::Cloudinary#cloudinary_image) or
[url_for()](https://metacpan.org/module/Cloudinary#url_for). Here is the original
image:

    %= cloudinary_image 'horses.jpg'; # no effects

<div class="row">
    <div class="thumbnail span4">
        <img src="http://res.cloudinary.com/demo/image/upload/w_300/horses.jpg" alt="horses.jpg">
        <h5>Original image</h5>
    </div>
</div>

The following examples modify the color saturation of the image. A negative
saturation value will reduce saturation and a positive will increase it:

    %= cloudinary_image 'horses.jpg', { effect => 'saturation:-70' }
    %= cloudinary_image 'horses.jpg', { effect => 'saturation:70' }

<div class="row">
    <div class="thumbnail span4">
        <img src="http://res.cloudinary.com/demo/image/upload/e_saturation:-70,w_300/horses.jpg" alt="horses.jpg">
        <h5>With saturation:-70 effect</h5>
    </div>
    <div class="thumbnail span4">
        <img src="http://res.cloudinary.com/demo/image/upload/e_saturation:70,w_300/horses.jpg" alt="horses.jpg">
        <h5>With saturation:70 effect</h5>
    </div>
</div>

You can also change the brightness or apply an sepia effect:

    %= cloudinary_image 'horses.jpg', { effect => 'brightness:-50' }
    %= cloudinary_image 'horses.jpg', { effect => 'sepia:50' }

<div class="row">
    <div class="thumbnail span4">
        <img src="http://res.cloudinary.com/demo/image/upload/e_brightness:-50,w_300/horses.jpg" alt="horses.jpg">
        <h5>With brightness:-50 effect</h5>
    </div>
    <div class="thumbnail span4">
        <img src="http://res.cloudinary.com/demo/image/upload/e_sepia:50,w_300/horses.jpg" alt="horses.jpg">
        <h5>With sepia:50 effect</h5>
    </div>
</div>

They even added an "oil-paint" effect.

    %= cloudinary_image 'horses.jpg', { effect => 'oil_paint' }

<div class="row">
    <div class="thumbnail span4">
        <img src="http://res.cloudinary.com/demo/image/upload/e_oil_paint,w_300/horses.jpg" alt="horses.jpg">
        <h5>With oil_paint effect</h5>
    </div>
</div>

## Chained Transformations

Cloudinary also provide [other transformations](http://cloudinary.com/documentation/image_transformations)
and they can all be chained. Here is an example with Arianna Huffington’s Facebok profile picture:

    %= cloudinary_image 'AriannaHuffington.png', { type => 'facebook' }
    %= cloudinary_image 'AriannaHuffington.png', { type => 'facebook', width => 150, height => 150, crop => 'thumb', gravity => 'face', radius => 20, effect => 'sepia' }

<div class="row">
    <div class="thumbnail span4">
        <img src="http://res.cloudinary.com/demo/image/facebook/AriannaHuffington.png" alt="AriannaHuffington.png">
        <h5>Original</h5>
    </div>
    <div class="thumbnail span4">
        <img src="http://res.cloudinary.com/demo/image/facebook/c_thumb,e_sepia,g_face,h_150,r_20,w_150/AriannaHuffington.png" alt="AriannaHuffington.png">
        <h5>Chained effects</h5>
    </div>
</div>

__Note__: Unfortunately, my module does not yet support "angle" and "overlay"
as shown in the Cloudinary blog. (Will either take 
[pull request](https://github.com/jhthorsen/cloudinary) or implement it on
[request](/contact)).

## Tweaking a web site's color scheme

Cloudinary provides the "hue" effect to change the color scheme of an image.
This can be quite useful when you tweak the CSS color scheme and don't
want to jump into [gimp](http://gimp.org) or photoshop to make changes to
the background image or other assets included in your design.

This example use the background image from the Cloudinary web site:

    %= cloudinary_image 'site_bg.jpg';
    %= cloudinary_image 'site_bg.jpg', { effect => 'hue:40' }

<div class="row">
    <div class="thumbnail span4">
        <img src="http://res.cloudinary.com/demo/image/upload/w_300/site_bg.jpg" alt="site_bg.jpg">
        <h5>Original</h5>
    </div>
    <div class="thumbnail span4">
        <img src="http://res.cloudinary.com/demo/image/upload/e_hue:40,w_300/site_bg.jpg" alt="site_bg.jpg">
        <h5>With hue:40 effect</h5>
    </div>
</div>

Want to try out the module? Complete API is documented on metacpan:

* [Cloudinary](https://metacpan.org/module/Cloudinary)
* [Mojolicious::Plugin::Cloudinary](https://metacpan.org/module/Mojolicious::Plugin::Cloudinary)
