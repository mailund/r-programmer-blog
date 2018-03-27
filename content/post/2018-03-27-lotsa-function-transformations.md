---
title: Lots of Function Transformations
author: Thomas Mailund
date: 2018-03-27T19:34:39+02:00
slug: transforming-functions-with-cases-calls
categories:
  - Metaprogramming
tags:
  - foolbox
---

The last couple of days I've been doing a lot of experimenting with a package for function rewriting: [`foolbox`](https://mailund.github.io/foolbox/). I am doing some function transformations in both `pmatch` and `tailr` and they look very much alike, so I figured I should collect the shared functionality in a separate package. After that, I found a work-around for the need for function rewriting in `pmatch`, so it isn't that necessary any longer, but playing around with `foolbox` has been fun and taught me a lot of tricks for metaprogramming that I hadn't thought about before.

I have written documentation on [`foolbox`'s homepage](https://mailund.github.io/foolbox/) so I won't repeat it here but refer you to

* [Transforming functions with `foolbox`](https://mailund.github.io/foolbox/articles/transforming-functions-with-foolbox.html) — general documentation of the package.
* [Partial evaluation with foolbox](https://mailund.github.io/foolbox/articles/partial-evaluation.html) — implementation of partial evaluation using `foolbox`.

I am pretty sure that you can implement the function transformations with invariants and pre- and post-conditions similar to mikefc's recent tweets:

{{< tweet 974905897100062720 >}}

{{< tweet 975294636477489155 >}}

{{< tweet 976053144219103232 >}}

{{< tweet 976783013496356864 >}}

{{< tweet 976916848959619072 >}}

I also think that some static type checking should be possible (for a subset of functions, of course, R is *way* too dynamic a language to try to handle all cases).

I was thinking of making a release later this week or sometime next week and then return to working on `pmatch` and `tailr`. I might play around it a bit more first, though. In any case, I would love if anyone else would take it for a spin and help me debug it.

