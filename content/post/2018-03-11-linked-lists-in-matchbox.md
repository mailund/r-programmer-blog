---
title: Linked lists in matchbox
author: Thomas Mailund
date: '2018-03-11'
slug: linked-lists-in-matchbox
categories:
  - Data-structures
  - Pattern-matching
tags:
  - matchbox
  - pmatch
  - tailr
---

I have started playing with data structures in [`matchbox`](https://github.com/mailund/matchbox) and the first structure I implement had to be linked lists. That is the most versatile data structure I use and it is missing from R. The `list` type in R is really a vector so you cannot modify it without copying all of it. Linked lists are easier to modify, and you can always prepend to them in constant time.

To define them using pattern matching constructers, we write:


```r
library(pmatch)
llist := NIL | CONS(car, cdr : llist)
```

I think I have implemented all of the functions I use on linked lists. I have made them all tail-recursive, so I can translate the recursive functions into looping versions using the [`tailr`](https://github.com/mailund/tailr) package.

All the implementations, as I hope you will agree, are straightforward:


```r
llength <- function(llist, acc = 0) {
    pmatch::cases(
        llist,
        NIL -> acc,
        CONS(car, cdr) -> llength(cdr, acc + 1)
    )
}
llength <- tailr::loop_transform(llength)

llrev <- function(llist, acc = NIL) {
    pmatch::cases(
        llist,
        NIL -> acc,
        CONS(car, cdr) -> llrev(cdr, CONS(car, acc))
    )
}
llrev <- tailr::loop_transform(llrev)

llcontains <- function(llist, elm) {
    pmatch::cases(
        llist,
        NIL -> FALSE,
        CONS(car, cdr) ->
            if (car == elm) TRUE else llcontains(cdr, elm)
    )
}
llcontains <- tailr::loop_transform(llcontains)

lltake <- function(llist, k, acc = NIL) {
    if (k == 0) return(llrev(acc))
    pmatch::cases(
        llist,
        NIL -> stop("There were less than k elements in the list"),
        CONS(car, cdr) -> lltake(cdr, k - 1, CONS(car, acc))
    )
}
lltake <- tailr::loop_transform(lltake)

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

For the map and filter functions I had to fix `tailr` to make it handle functions that are local variables, so you need to install the development version of the package to make these work.


```r
llmap <- function(llist, f, acc = NIL) {
    pmatch::cases(
        llist,
        NIL -> llrev(acc),
        CONS(car, cdr) -> llmap(cdr, f, CONS(f(car), acc))
    )
}
llmap <- tailr::loop_transform(llmap)

llfilter <- function(llist, p, acc = NIL) {
    pmatch::cases(
        llist,
        NIL -> llrev(acc),
        CONS(car, cdr) ->
            if (p(car)) llfilter(cdr, p, CONS(car, acc))
            else llfilter(cdr, p, acc)
    )
}
llfilter <- tailr::loop_transform(llfilter)
```

Finally, there are some functions from translating to and from linked lists. I found it simpler to implement these via loops than recursively, so nothing fancy is going on here.


```r
llist_from_list <- function(x) {
    llist <- NIL
    n <- length(x)
    while (n > 0) {
        llist <- CONS(x[[n]], llist)
        n <- n - 1
    }
    llist
}

#' @export
as.list.llist <- function(x, all.names = FALSE, sorted = FALSE, ...) {
    n <- llength(x)
    v <- vector("list", length = n)
    i <- 1
    while (i <= n) {
        v[i] <- x$car
        i <- i + 1
        x <- x$cdr
    }
    v
}

#' @export
as.vector.llist <- function(x, mode = "any") {
    unlist(as.list(x))
}
```
