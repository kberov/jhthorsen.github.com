---
layout: post
title: "Wow, Moose is cool!"
---

I was introducing [Moose](http://search.cpan.org/dist/Moose) (and perl oo)
to a java guy the other day, and he replied: "No, shit. Is that possible?",
"Now I understand the fuzz about multiple inheritance" and "Wow, Moose is
cool!".

I must confess: It brings comfort to my heart to hear a
[Java](http://en.wikipedia.org/wiki/Java_%28programming_language%29) guy
talk down on his own language, but it's even sweeter to hear something
nice about perl.

But back to the topic: What was so cool about Moose? The short answer is
[Moose::Role](http://search.cpan.org/dist/Moose/lib/Moose/Manual/Roles.pod).
I had a hard time understanding roles, and the usage for them, but after
getting the short answer "You use roles to build your classes, and your
classes to build objects" - it suddenly got a lot clearer to me.

Roles to build classes, ey? Yes, instead of putting functionality in
different packages, and inheriting from them, you write roles and
_consume_ their functionality in a class, which imho gives me a lot
cleaner interface.

I try to look at Roles like something like this:

    package Foo;
    do MyOtherFile.pm;
    1;

But of course there's a lot more [sugar](http://search.cpan.org/dist/Moose/lib/Moose/Manual/Unsweetened.pod)
to it in "Mooseland" :-)
