---
title: Matchbox and CMD CHECK
date: 2018-03-08T06:59:09+01:00
tags:
    - roxygen
    - pmatch
    - matchbox
categories:
    - Data-structures
    - Patter-matching
    - Package-development
---

Ok, first, the [package I wrote about yesterday](https://mailund.github.io/r-programmer-blog/2018/03/07/help-me-choose-a-name/) will be called `matchbox`, following Dmytro Perepolkin's suggestion (thanks!). You can get it at [GitHub](https://github.com/mailund/matchbox).

There isn't much to it yet since I haven't really started implementing the data structures I want to put in it. I plan to implement most of the structures from [Function Data Structures in R](http://amzn.to/2G3Tkvk) but using pattern matching and tail-recursion optimisation, and I will write about it here.

I have implemented some linked-lists functions, but a `CMD CHECK` of the package fails.

If I run the functions through `tailr`, I get this interesting Note:

```
Error in attr(e, "srcref")[[i]] : subscript out of bounds
Calls: <Anonymous> ... <Anonymous> -> collectUsage -> collectUsageFun -> walkCode -> h
Execution halted
llength: Error while checking: subscript out of bounds
llrev: Error while checking: subscript out of bounds
```

I have no idea what is happening here.

If I disable the tail-recursion optimisation, I get this Note:

```
llength: no visible global function definition for ‘llength<-’
llength: no visible binding for global variable ‘car’
llrev: no visible global function definition for ‘llrev<-’
llrev: no visible binding for global variable ‘car’
Undefined global functions or variables:
  car llength<- llrev<-
```

This, I am pretty sure, is because of the pattern matching DSL in `pmatch`. The `llength` function, for example, is define like this:

```r
llength <- function(llist, acc = 0) {
    pmatch::cases(
        llist,
        NIL -> acc,
        CONS(car, cdr) -> llength(cdr, acc + 1)
    )
}
```

and the `cases` syntax uses the assignment operator. Therefore, the check thinks we are using the replacement operator `length<-`. The 

```r
CONS(car, cdr) -> llength(cdr, acc + 1)
```

expression is translated into

```r
llength(cdr, acc + 1) <- CONS(car, cdr)
```

by the parser, and a function call on the left-hand side of an assignment is interpreted as a replacement operator. So here, at least, I think I understand the problem. I just don't know how to tell the package check that I know what I am doing and it shouldn't worry about it.

Help!?
