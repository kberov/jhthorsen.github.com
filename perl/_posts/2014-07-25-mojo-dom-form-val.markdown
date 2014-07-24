---
layout: post
title: "How to extract val() from a form using #Mojolicious"
tag: perl
category: Programming
---

## Introduction

Mojolicious just introduced Mojo::DOM::val() in version 5.17. It's a method
for extracting the value from any form field, instead of running all the
  tedious queries for each input type. This means that you can do things like:

    use Mojo::Base -strict;
    use Mojo::UserAgent;

    my $ua = Mojo::UserAgent->new;
    my $dom = $ua->get("https://www.facebook.com")->res->dom;

    say $dom->at(

## Prerequisits

## Summary

## Resources

* Running demo:
* Code:
* Issues:

