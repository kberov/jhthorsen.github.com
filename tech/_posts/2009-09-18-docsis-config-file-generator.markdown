---
layout: post
title: Online DOCSIS config file editor
---

I've written an [online DOCSIS config file editor](http://flodhest.net/services/docsis)
which (of course) can be used to generate config files for equipment that
follow the [DOCSIS specification](http://en.wikipedia.org/wiki/DOCSIS).

The frontend is written using [Catalyst](http://www.catalystframework.org/),
and the "backend" use [DOCSIS::ConfigFile](http://search.cpan.org/perldoc?DOCSIS::ConfigFile),
meaning the whole thing is powered by [Perl](http://perl.org).

(The frontend will soon support "shared secret", which the backend already
supports)
