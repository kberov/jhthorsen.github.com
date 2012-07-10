---
layout: post
title: CatalystX::Controller::Sugar
tag: perl
category: Programming
---

I've written a module I think is rather useful:
[CatalystX::Controller::Sugar](http://search.cpan.org/perldoc?CatalystX::Controller::Sugar).
This module (will hopefully) make chained actions be your default when
writing a controller in [Catalyst](http://search.cpan.org/perldoc?Catalyst::Runtime).
I remember when I first started looking at Catalyst - I didn't see the reason
for doing chained actions, and I certainly didn't understand how they worked.
I still think it's a pain to set it up, but hopefully it's a bit easier using
the sugar module.

In addition to sugar for chains, it exports some other functions, which I
use most the time. This is something I think is a pain:

    # 139 characters
    sub foo :Chain('/') PathPart('') CaptureArgs(0) {
      my $self = shift;
      my $c = shift;
      $c->stash->{'answer_to_everything'} = 42;
    }

...which can be written this way, with sugar:

    # 53 characters
    chain sub {
        stash answer_to_everything => 42;
    };

I hardly ever use `$self`, but I wery often use `stash()`, `session()` and
`forward()` so that's why I've chosen to export those functions (among
some others). The module is also quite simple to use:

    use CatalystX::Controller::Sugar;
    # your controller code
    1;

...instead of:

    use CatalystX::Controller;
    use Moose;
    BEGIN { extends 'Catalyst::Controller' }
    # your controller code
    1;

Does my pod suck? Is the module not flexible enough? Let me know.
