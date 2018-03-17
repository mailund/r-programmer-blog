---
title: Building a package that uses pattern matching
author: Thomas Mailund
date: 2018-03-17T14:35:16+01:00
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

There's a couple of reasons that it fails, and it isn't just failing on Travis. It is failing because the byte-complier croaks on some of the DSL constructions and the CMD CHECK on others.

## Problems with byte-compilation

The [first problem](https://github.com/mailund/matchbox/issues/8) is with constructions where it, at first glance, looks like you are assigning to literals.

If we define a linked-list type like this


```r
library(pmatch)
llist := NIL | CONS(car, cdr:llist)
```

then we an write a function that checks if a list is empty like this:


```r
is_llist_empty <- function(llist) {
    pmatch::cases(
        llist,
        NIL -> TRUE,
        otherwise -> FALSE
    )
}
```

The `->` assignments are part of the `pmatch` DSL and not really assignments. Which is good, because it is incorrect to assign to `TRUE` and `FALSE`, just as it would be an error to assign to `1` or `"foo"`.

The function works fine, though:


```r
empty <- NIL
non_empty <- CONS(1, NIL)

is_llist_empty(empty)
```

```
## [1] TRUE
```

```r
is_llist_empty(non_empty)
```

```
## [1] FALSE
```

Incidentally, if you thought it would be simpler to just compare `llist == NIL`, you would be right. That would be simpler. But it doesn't work with `pmatch` because `NIL` is actually just `NA` with a `class` attribute, and any comparison with `NA` gives you `NA` and not a boolean. So we do need pattern matching of some kind.

So what's the problem? Clearly the function works!

Well, yes, but only because I do not try to byte-compile it.


```r
compiler::cmpfun(is_llist_empty)
```

```
## Error: bad assignment: 'TRUE <- NIL'
```

If you put a function in a package, it will be byte-compiled by  default. You can turn this off in your `DESCRIPTION` file, but generally you want the optimisation you get from byte-compilation, so you do not *want* to turn it off.

You can cheat the byte-compiler using variables


```r
is_llist_empty <- function(llist) {
    t <- TRUE
    f <- FALSE # to satisfy lintr
    pmatch::cases(
        llist,
        NIL -> t,
        otherwise -> f
    )
}
compiler::cmpfun(is_llist_empty)
```

```
## function(llist) {
##     t <- TRUE
##     f <- FALSE # to satisfy lintr
##     pmatch::cases(
##         llist,
##         NIL -> t,
##         otherwise -> f
##     )
## }
## <bytecode: 0x7f91699fa540>
```

But consider this function:


```r
llcontains <- function(llist, elm) {
    pmatch::cases(
        llist,
        NIL -> FALSE,
        CONS(car, cdr) ->
            if (car == elm) TRUE else llcontains(cdr, elm)
    )
}
llcontains <- tailr::loop_transform(llcontains)
```

I am not byte-compiling it directly but I am inside `tailr::loop_transform`, but more importantly, in this function I can "assign" `NIL -> FALSE` and I do not get any errors when I build the package.

Similarly, I do not get any problems with this function


```r
lldrop <- function(llist, k, acc = NIL) {
    if (k == 0) return(llist)
    pmatch::cases(
        llist,
        NIL -> stop("There were less than k elements in the list"),
        CONS(car, cdr) -> lldrop(cdr, k - 1)
    )
}
lldrop <- tailr::loop_transform(lldrop)
```

even though it is just as much a problem to assign to a call to `stop` as it is to assign to `TRUE`.

The reason that I do not have problems with these two, as you have no doubt guessed, is that I run them through `tailr::loop_transform`. This function modifies the input function and replaces the `pmatch::cases` DSL with a series of `if`-`else`-statements. The byte-compiler doesn't see the DSL so it doesn't complain about the odd "assignments".

After the `tailr` transformation, the functions actually look like this:


```r
llcontains
```

```
## function (llist, elm) 
## {
##     .tailr_llist <- llist
##     .tailr_elm <- elm
##     callCC(function(escape) {
##         repeat {
##             llist <- .tailr_llist
##             elm <- .tailr_elm
##             if (!rlang::is_null(..match_env <- pmatch::test_pattern(llist, 
##                 NIL))) 
##                 with(..match_env, escape(FALSE))
##             else if (!rlang::is_null(..match_env <- pmatch::test_pattern(llist, 
##                 CONS(car, cdr)))) 
##                 with(..match_env, if (car == elm) 
##                   escape(TRUE)
##                 else {
##                   .tailr_llist <<- cdr
##                   .tailr_elm <<- elm
##                 })
##         }
##     })
## }
## <bytecode: 0x7f9169afe5c0>
```

```r
lldrop
```

```
## function (llist, k, acc = NIL) 
## {
##     .tailr_llist <- llist
##     .tailr_k <- k
##     .tailr_acc <- acc
##     callCC(function(escape) {
##         repeat {
##             llist <- .tailr_llist
##             k <- .tailr_k
##             acc <- .tailr_acc
##             {
##                 if (k == 0) 
##                   escape(llist)
##                 if (!rlang::is_null(..match_env <- pmatch::test_pattern(llist, 
##                   NIL))) 
##                   with(..match_env, escape(stop("There were less than k elements in the list")))
##                 else if (!rlang::is_null(..match_env <- pmatch::test_pattern(llist, 
##                   CONS(car, cdr)))) 
##                   with(..match_env, {
##                     .tailr_llist <<- cdr
##                     .tailr_k <<- k - 1
##                   })
##             }
##         }
##     })
## }
## <bytecode: 0x7f9169917db8>
```

Now, I don't want to run everything through the tail-recursion optimisation, of course. Not all functions *can* be transformed, and those that can but do not need to, will get slower.

Perhaps, though, I will need to write a similar transformation function in the `pmatch` package that rewrites calls to `cases`. I think that would be the solution to this issue.

## Problems with CMD CHECK

So, I think I can solve the byte-compiler issue, but I have [more of a problem with package checking](https://github.com/mailund/matchbox/issues/9).

There are some issues that are easy to solve. A package check will complain if there are unbound variables, which there are when we pattern match in `pmatch::cases`. I can solve that by defining the variables and giving them dummy values—those variables will never be used, but it will shut up the checker.

What I don't know how to handle is this error:

```
Error in attr(e, "srcref")[[i]] : subscript out of bounds
Calls: <Anonymous> ... <Anonymous> -> collectUsage -> collectUsageFun -> walkCode -> h
```

I get it for the functions I transform using `tailr`. I figured it was because `tailr::loop_transform` doesn't set the `"srcref"` attribute, so I tried changing that. I did something like this, just inside the `loop_transform` function:


```r
lldrop <- function(llist, k, acc = NIL) {
    if (k == 0) return(llist)
    pmatch::cases(
        llist,
        NIL -> stop("There were less than k elements in the list"),
        CONS(car, cdr) -> lldrop(cdr, k - 1)
    )
}
lldrop_tr <- tailr::loop_transform(lldrop)
attributes(lldrop_tr)
```

```
## NULL
```

```r
lldrop_tr
```

```
## function (llist, k, acc = NIL) 
## {
##     .tailr_llist <- llist
##     .tailr_k <- k
##     .tailr_acc <- acc
##     callCC(function(escape) {
##         repeat {
##             llist <- .tailr_llist
##             k <- .tailr_k
##             acc <- .tailr_acc
##             {
##                 if (k == 0) 
##                   escape(llist)
##                 if (!rlang::is_null(..match_env <- pmatch::test_pattern(llist, 
##                   NIL))) 
##                   with(..match_env, escape(stop("There were less than k elements in the list")))
##                 else if (!rlang::is_null(..match_env <- pmatch::test_pattern(llist, 
##                   CONS(car, cdr)))) 
##                   with(..match_env, {
##                     .tailr_llist <<- cdr
##                     .tailr_k <<- k - 1
##                   })
##             }
##         }
##     })
## }
## <bytecode: 0x7f91685cd1b8>
```

```r
attr(lldrop_tr, "srcref") <- attr(lldrop, "srcref")
attributes(lldrop_tr)
```

```
## $srcref
## function(llist, k, acc = NIL) {
##     if (k == 0) return(llist)
##     pmatch::cases(
##         llist,
##         NIL -> stop("There were less than k elements in the list"),
##         CONS(car, cdr) -> lldrop(cdr, k - 1)
##     )
## }
```

```r
lldrop_tr
```

```
## function(llist, k, acc = NIL) {
##     if (k == 0) return(llist)
##     pmatch::cases(
##         llist,
##         NIL -> stop("There were less than k elements in the list"),
##         CONS(car, cdr) -> lldrop(cdr, k - 1)
##     )
## }
## <bytecode: 0x7f91685cd1b8>
```

It is a bit of a cheat since I now claim that the *modified* function actually consists of the same code as the original, but I think that would be the way to go. If people want to see the source code of a function, they want the human readable version, not the transformed version.

It doesn't help, though. I still get the error.

I don't know what is causing this or how to debug it. I have never delved deep into package checking. I would love some pointers!
