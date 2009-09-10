---
layout: post
title: More perl modules
tag: perl
category: Programming
---

I'm working on some more perl-modules now:
[YAML::Object](http://search.cpan.org/dist/YAML-Object) and
[POE::Component::TFTPd](http://search.cpan.org/dist/POE-Component-TFTPd).
I've also fixed some issues with SNMP::Effective, and written a 
[new implementation](http://github.com/jhthorsen/snmp-effective/tree/net-snmp),
that uses Net::SNMP instead of SNMP.

The YAML-module is a result of bad typing: I'm quite sick of doing
&#36;config->{typoo}{key}. YAML::Object enables you to use method notation,
so the above would become $config->typoo->key, and calling key() on an
undef value will barf with a nice error message.

I'm pretty exited about the POE::Component, since I've never written
anything quite like it before. Check out
[POE](http://search.cpan.org/dist/POE) If you haven't already done so,
it's really cool :)

