---
layout: post
title: 'Line noise: parentheses'
tag: perl
category: Programming
---

I've been discussing how bad perl code looks and I'm a bit surprised:
I consider () more noisy than $, %, @ and friends, while the people I
discuss this with, really likes parentheses. Consider this:

    push(@text, sprintf('I got %i foos', int(shift(@{ $obj->get_foo() }))));

Versus:

    push @text, sprintf 'I got %i foos', int shift @{ $obj->get_foo };

I don't understand how the first one is less noisy than the second (!).
I also don't understand how you can maintain or read the first one.

Disclaimer: Yes, I know the example code doesn't make any sense.
