---
title: Building a package that uses pattern matching
author: Thomas Mailund
date: 2018-03-17T14:35:16+01:00
draft: true
slug: building-a-package-that-uses-pattern-matching
categories:
  - Pattern-matching
  - Package-development
  - DSL
tags:
  - pmatch
  - matchbox
---

After a week spend [programming string algorithms in C](https://github.com/mailund/gsa-read-mapper)—for teaching purposes, I am not working on a new read-mapper—it is nice to get back to programming in R. I made a new release of `tailr` today, so that is good, but what I really wanted to work on was `matchbox`.

Where I left it last weekend, I had implemented various data structures—lists, stacks, queues, and search-trees—although search trees only with insertion yet. I *wanted* to work on the search trees today, first to implement plotting code to visualise them (for debugging purposes) and then to implement deletion. First, however, I wanted to make sure the package was in a good state.

It isn't. It is actually the only package I have right now that doesn't make it through Travis-CI.

![](https://mailund.github.io/r-programmer-blog/images/2018-03-17-travis-status-failing-matchbox.png)

