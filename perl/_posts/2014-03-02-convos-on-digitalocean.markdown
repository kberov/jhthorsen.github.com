---
layout: post
title: "Howto set up Convos on @digitalocean"
tag: perl, irc
category: Programming
---

## Introduction

From [convos.by](http://convos.by):

> Convos is the simplest way to use IRC. It is always online, and accessible
> to your web browser, both on desktop and mobile. Run it on your home server,
> or cloud service easily. It can be deployed to Heroku or Docker-based cloud
> services, or you can just run it as a normal Mojolicious application, using
> any of the Deployment Guides.

So now I'm going to show how easy it is to deploy Convos on a cloud service.

The cloud service I've chosen is [DigitalOcean](https://www.digitalocean.com),
because it is incredible easy to set up and they have a sane payment plan.

Want to see a running version of Convos? Check out the
[demo](http://demo.convos.by) page which was set up using the instructions in
this tutorial.

## Prerequisits

* You need an account on [DigitalOcean](https://www.digitalocean.com)
* You need to create a Droplet running Ubuntu 13.10 to have some sort of sane version of Perl and Redis. Choose the cheapest droplet they have to begin with.

## Install Convos

Log into the droplet you created in the previous step.

    $ ssh -l root $DROPLET_IP_FROM_DIGITAL_OCEAN

You are now logged in as root. Next step is to install dependencies.

    $ apt-get install make gcc redis-server libio-socket-ssl-perl libio-socket-ip-perl libev-perl

We need "make" and "gcc" since Convos depend on some modules which need to be compiled.
"[redis-server](http://redis.io/)" is the database where we will store our data. The
rest are libraries which will make Convos able to handle SSL, IPv6 and run faster.

Next we want to run Convos as a non-priviledged user. We will do that by adding
the "convos" user and run the rest of the commands as "convos":

    $ adduser convos
    $ su - convos

Next install convos and start the server:

    $ curl -L http://convos.by/install.sh | bash -
    $ cd convos-release
    $ mkdir log
    $ ./vendor/bin/carton exec hypnotoad script/convos

That's it! You can now point your browser to
"http://$DROPLET_IP_FROM_DIGITAL_OCEAN:8080" to start using Convos.

## Convos on port 80 instead of 8080

To increase security and let Convos be accessible on port 80, we will use
[ufw](https://help.ubuntu.com/community/UFW).

If you are still "convos" user, you need to run "exit" to get back to "root".
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

You could also fire up nginx or another web server, but there's no good reason for that if you are only setting up Convos.

## Autostart Convos when the server boots

If you restart the server now, Convos will not start. You can autostart the
server by adding a command to "/etc/rc.local", right before "exit 0" or
somewhere before the end of the file.

    /usr/bin/sudo -u convos bash -c 'cd /home/convos/convos-release; ./vendor/bin/carton exec hypnotoad script/convos'

## Other tips

You probably want to set up a DNS record that points to the droplet's IP
address. You can do this by registering a domain on [gandi](http://gandi.net)
and configure the DNS on [cloudflare](http://cloudflare.com).

## Summary

After following these steps, you have IRC with you anywhere you go, as long
as you have your phone, table or laptop and power and internet.

## Resources

* Running demo: [http://demo.convos.by](http://demo.convos.by)
* Issues: [https://github.com/Nordaaker/convos/issues](https://github.com/Nordaaker/convos/issues)
* Code: [https://github.com/Nordaaker/convos](https://github.com/Nordaaker/convos)

Any [feedback](https://github.com/Nordaaker/convos/issues) is more than welcome. Come talk to us on IRC: #convos on irc.perl.org.

