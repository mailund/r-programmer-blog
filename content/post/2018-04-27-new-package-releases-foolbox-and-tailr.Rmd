---
title: "New Package Releases: foolbox and tailr"
author: Thomas Mailund
date: 2018-04-27
categories:
  - Metaprogramming
tags:
  - foolbox
  - tailr
---

I have just released version 0.1.0 of [foolbox](https://mailund.github.io/foolbox/) and version 0.1.2 of [tailr](https://mailund.github.io/tailr/). I haven't actually done much on the packages the last three weeks, and they have been very close to these releases for a while, but now I had the spare time and energy to actually send them off.

For `foolbox`, I think I have all the functionality implemented that I need for my own packages. I have already updated `pmatch` to use it. Now, one of the coming days, I want to see if I can implement `tailr` using `foolbox`. This was the goal from the start, but it is a daunting task since `tailr` is doing a lot of function rewriting.
