---
layout: post
title: "How to deploy #Mojolicious apps on @DigitalOcean"
tag: perl
category: Programming
---

## Introduction

[Mojolicious](http://mojolicio.us) is truly a modern web framework. It keeps
up to date with the HTTP, HTML, WebSockets and JSON specifications so you
don't have to worry about doing that right. It's a framework where you
implement the core business logic, while everything else Just Works (tm).

[DigitalOcean](https://digitalocean.com) is "cloud hosting, built for
developers". It's relatively new, but the user base has grown rapidly. I
think the reason is that the pricing plan is understandable and affordable,
and the setup is extremely simple.

## Prerequisites

You need to know basic shell and/or have an interest in seeing how easy it
is to deploy a [Perl](http://perl.org) based web application.

## The application

I've chosen [Timer](https://github.com/jhthorsen/timer) as the example
application, since it's quite simple but still has the amount of
dependencies to put it in a "real app" category. It also doesn't require
a database, which makes it more Perl focused.

## Step 1: Setup DigitalOcean

You need to create an account and a droplet on
[DigitalOcean](https://www.digitalocean.com/).

Follow the "[How To Create Your First DigitalOcean Droplet Virtual Server](https://www.digitalocean.com/community/articles/how-to-create-your-first-digitalocean-droplet-virtual-server)"
instructions if you need guidance.

Notes about the how to:

* Step Three—Select your Droplet's Type and Size

  You only need the smallest droplet size for this tutorial. I actually
  still just have the smallest droplet for my account, where I run
  four Mojolicious applications with a [Redis](http://redis.io) backend.

* Step Five—Select the Droplet Image

  I strongly suggest choosing "Ubuntu 13.10 x64".

* Step Seven—Log In To Your Droplet

  After you have logged in to your droplet (as root), you can continue
  to "Step 2" below.

## Step 2: Install dependencies

So now you have set up DigitalOcean and you are logged in as "root".

Next we will install dependencies using "apt-get".

    $ apt-get install make gcc cpanminus rubygems git-core libio-socket-ssl-perl libio-socket-ip-perl libev-perl

* gcc, cpanminus and rubygems

  We need a compiler since some of the dependencies of the "Timer" application
  are written in XS which need to be compiled. cpanminus is the easiest way
  to install Perl dependencies and rubygems is used to install
  [sass](http://sass-lang.com).

* git-core

  I suggest using git to clone the [Timer](https://github.com/jhthorsen/timer)
  instead of just downloading the tar-ball, since it makes it easier to pull in
  changes later.

* libio-socket-ssl-perl and libio-socket-ip-perl

  These two dependencies are not really required to complete the setup, but
  they are required if you want the application to communicate over IPv6 or SSL.

* libev-perl

  [EV](https://metacpan.org/release/EV) is also strictly not required, but will
  enable Mojolicious to handle requests faster.

## Step 3: Add a user

We don't want to run the "Timer" application as "root" for security reasons,
so we need to add a user with the username "bender".

    $ adduser bender
    $ usermod -a -G sudo bender

NOTE! Choose a [safe password](https://howsecureismypassword.net/)!

NOTE! We are adding the user to the "sudo" group for convenience. You might
want to remove it from that group later to increase security.

## Step 3: Download and start the application

Now that all the basic prerequisites are in place, you can install the
"Timer" application as the user "bender".

    # Become "bender" if you are still "root"
    $ su - bender

    # Download the application
    $ git clone https://github.com/jhthorsen/timer.git

    # Enter the cloned repository and install Timer dependencies
    $ cd timer
    $ cpanm -n --sudo --installdeps .

    # Start the application
    $ hypnotoad script/timer

[Hypnotoad](https://metacpan.org/pod/Mojo::Server::Hypnotoad) is a full
featured, UNIX optimized web server written in Perl. This means that
after you have run the "hypnotoad" command, you can access your
application on <code>http://$DROPLET_IP:8080/</code>. The $DROPLET_IP
is the same IP that you logged into after you set up the Droplet.

## Step 4: Listen to port 80, instead of 8080

We will now set up firewall rules using
[ufw](https://help.ubuntu.com/community/UFW). This will make the server more
secure but also allow us to access the "Timer" application on the
standard port 80.

If you are still the "bender" user, you need to run "exit" to become "root".
When you are "root", run the commands below to set up ufw.

NOTE! It is very important that you include the "ufw allow ssh" line, or else
you will be locked out of your own droplet. If that happens, you need to start
a console from web, by logging into [DigitalOcean](https://cloud.digitalocean.com/).

    # basic firewall rules: Deny everything except HTTP and SSH traffic
    $ ufw default deny incoming
    $ ufw default allow outgoing
    $ ufw allow ssh
    $ ufw allow 80/tcp
    $ ufw allow 8080/tcp

    # forward traffic from port 80 to 8080
    $ cat <<FIREWALL_RULES >> /etc/ufw/before.rules
    *nat
    :PREROUTING ACCEPT [0:0]
    -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
    -A OUTPUT -o lo -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 8080
    COMMIT
    FIREWALL_RULES

    # start the firewall
    $ ufw enable

## Step 5: Autostart the application when the server boots

If you restart the server now, the Timer application will not start. You can
autostart the server by adding a command to "/etc/rc.local", right before
"exit 0" or somewhere before the end of the file.

    /usr/bin/sudo -u bender hypnotoad /home/bender/timer/script/timer

## You are done

As you can see from this tutorial, it's not  hard or expensive to get your
Perl based web application up and running in the cloud.

Got questions or feedback? Contact me on
[twitter](http://twitter.com/jhthorsen),
<abbr title="batman on irc.perl.org">IRC</abbr>
or drop me an [email](mailto:jhthorsen@cpan.org).

## Questions and answers

* Hypnotoad...? What about nginx or apache?

  I don't think you want nginx to speed up the application. You probably rather
  want a <abbr title="Content Delivery Network">CDN</abbr> instead. I personally
  think [Cloudflare](http://cloudflare.com) is awesome. The reason for that
  is a combination of company values and quality of service.

* How to run multiple web apps on the same server?

  You can run multiple Mojolicious application using
  [Toadfarm](https://metacpan.org/release/Toadfarm). Toadfarm is a "wrapper"
  around Hypnotoad, which allow you to route different requests (using HTTP
  header rules) to different Mojolicious apps.

  If you have apps written in other languages, you probably need a
  [web server](http://nginx.com) or maybe you can use
  [Mojolicious::Plugin::CGI](https://metacpan.org/pod/Mojolicious::Plugin::CGI).

* What about a domain name?

  I buy my domain names from [Gandi](http://gandi.net) because of their "no
  bullshit" (tm) and then I my DNS records from [Cloudflare](http://cloudflare.com).
