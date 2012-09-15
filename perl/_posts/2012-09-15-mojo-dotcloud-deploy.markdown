---
layout: post
title: "Howto deploy #Mojolicious to @dotcloud"
tag: perl
category: Programming
---

After sending some [tweets](https://twitter.com/jhthorsen/status/246716307741999106)
with dotcloud I've figured out how to deploy [Mojolicious](http://mojolicio.us) to
[dotcloud](http://dotcloud.com) as a perl-worker.

The way I previously deployed was using the standard
[perl](http://docs.dotcloud.com/0.4/services/perl/) service, with a uWSGI
frontend. This is quite easy, but it does not enable me to use the internal
Mojo::IOLoop, which I really like.

DISCLAIMER: When reading this howto, you should already know the basics about
Mojolicious and dotcloud.

So here is how I did it:

## dotcloud.yml

This file is the build file used by dotcloud to figure out which services
to set up. Here is an example file that I use:

    www:
      type: perl-worker
      config:
        perl_version: v5.16.x
      ports:
        www: http

The "magical" config setting here is "ports". This allow the perl-worker to
be accessible from the outside. Which port is given to you is then set in
the [environment.yml](http://docs.dotcloud.com/0.4/guides/environment/)
file created by dotcloud.

## supervisord.conf

The next file to set up is [supervisord.conf](http://docs.dotcloud.com/0.4/guides/daemons/#guides-define-daemons)
file which tells dotcloud which application to run. Here the file I use:

    [program:cool_app]
    command = /home/dotcloud/current/script/dotcloud.sh

This simply tells Supervisor to execute the "command" once pushed to dotcloud.
The shell script then need to start your mojo app the right way. Here is the
content of "dotcloud.sh":

    #!/bin/sh
    export ENVIRONMENT_FILE="/home/dotcloud/environment.yml";
    export MOJO_LOG_LEVEL="info";

    # export environment.yml as shell variables
    $( perl -p -e's/:\s+/=/;s/^/export /' $ENVIRONMENT_FILE );

    if [ "x$DOTCLOUD_PROJECT" = "xcool_app_test" ]; then
        export MOJO_LOG_LEVEL="debug";
    fi

    exec /home/dotcloud/current/script/cool_app daemon --listen "http://*:$PORT_WWW";

The trick is to fetch the "PORT_WWW" variable from the environment.yml file
and then start the "cool_app" with the correct listen port. The "if" in the
middle is a trick I use to set the debug level once pushed to my test-instance.
It is not required.

NOTE: Remember to make both "script/cool_app" and "script/dotcloud.sh" executable.

## Pushing the app to dotcloud

After creating the files above, your directory tree should look something like
this:

    cool_app.conf      # app config file
    dotcloud.yml
    lib/               # your mojo app
    Makefile.PL        # build file for your mojo app
    public/            # mojo public files
    script/cool_app    # executable
    script/dotcloud.sh # executable
    supervisord.conf
    t/                 # perl unittests

NOTE: The directory structure will look different if you're deploying a mojo
lite app.

Run the commands below to create and push the app:

    dotcloud create cool_app
    dotcloud push cool_app

After this you should see something like this in the output from "dotcloud":

    Deployment finished. Your application is available at the following URLs
    www: http://cool_app-username.dotcloud.com/

And then you're done!

## Other resources

The downside about this is that you can't serve your static files directly
with nginx. To remove this "burden" from your mojo app, you should consider
setting up [cloudflare](http://cloudflare.com) in front of your application.
It's a kick ass service for both DNS and content delivery.
