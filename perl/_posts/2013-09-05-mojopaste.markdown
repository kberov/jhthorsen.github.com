---
layout: post
title: "Mojopaste - A #pastebin based on #Mojolicious"
tag: perl
category: Programming
---

    // From errno.h
    #define EPASTEBINAGAIN 133 /* mojopaste */

Today I released my 13th [Mojolicious](https://metacpan.org/release/Mojolicious)
based project to CPAN, but the 1st open source Mojolicious based application.

It feels good.

The [application](https://metacpan.org/module/App::mojopaste) is a pastebin.
That is a web application which you can paste text to, hit the "Paste" button
and it will save it and generate a unique URL which you can share with other
people.

Yes. A standard pastebin. So why?

There's about [20 million](https://www.google.com/search?q=pastebin) pastebin
search results on Google and there's about [40](https://metacpan.org/search?q=pastebin)
pastebin related modules on CPAN, but I don't think there's any Mojolicious
based. So that's why I wrote it: [mojopaste](https://metacpan.org/module/App::mojopaste)
is super easy to install, as long as you have [perl](http://perl.org) from
this century.

Who could be interested?

* Maybe you have the need to run a pastebin internally at work.
* You just fancy having your own pastebin.

Want to try it out? Check out [mojopaste](http://p.thorsen.pm) on my server.

What about the future: Version 0.04 will look better on the iPhone and will
probably have different input names to make it a *bit* harder for robots to
paste. Got other ideas for improvements?  Comment below or contact
[batman](irc://irc.perl.org/batman) @ irc.perl.org. (I'm usually in the
[#mojo](http://irclog.perlgeek.de/mojo/2013-08-13) channel)
