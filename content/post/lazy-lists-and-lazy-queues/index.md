---
title: "Lazy lists and lazy queues"
date: '2018-10-02T09:13:01+02:00'
tags:
  - scope-rules
categories:
  - Non-standard evaluation
draft: true
---


## Lazy lists





```r
library(pmatch)

linked_list := NIL | CONS(car, cdr)
toString.linked_list <- function(llist)
  cases(llist, NIL -> "[]",
        CONS(car, cdr) -> paste(car, "::", toString(cdr)))
print.linked_list <- function(llist)
  cat(toString(llist), "\n")

# lazy lists are thunks
make_thunk <- function(expr, klass = NULL) {
  force(expr)
  structure(function() expr, class = klass)
}
make_lazy_thunk <- function(expr, klass = NULL) {
  structure(function() expr, class = klass)
}

toString.lazy_list <- function(x) {
  cases(x(),
        NIL -> "<>",
        CONS(car, cdr) -> paste(car, ":: <...>"))
}
print.lazy_list <- function(x)
  cat(toString(x), "\n")


lazy_nil   <- make_thunk(NIL, "lazy_list")
lazy_cons  <- function(car, cdr) make_thunk(CONS(car, cdr), "lazy_list")
delay_cons <- function(car, cdr) make_lazy_thunk(CONS(car, cdr), "lazy_list")

lazy_to_llist <- function(lazy)
  cases(lazy(),
        NIL -> NIL,
        CONS(car, cdr) -> CONS(car, lazy_to_llist(cdr)))

x <- purrr::reduce(1:5, ~ lazy_cons(.y, .x), .init = lazy_nil)
x
```

```
## 5 :: <...>
```

```r
lazy_to_llist(x)
```

```
## 5 :: 4 :: 3 :: 2 :: 1 :: []
```

```r
make_noise <- function(val) {
  cat("I see", val, "\n")
  val
}
y <- delay_cons(make_noise(1), delay_cons(make_noise(2), lazy_nil))

lazy_car <- function(lst) lst()$car
lazy_cdr <- function(lst) lst()$cdr

lazy_car(y)
```

```
## I see 1
```

```
## [1] 1
```

```r
lazy_car(y)
```

```
## [1] 1
```

```r
lazy_cdr(y)
```

```
## I see 2 
## 2 :: <...>
```

```r
lazy_car(lazy_cdr(y))
```

```
## [1] 2
```

```r
lazy_cdr(lazy_cdr(y))
```

```
## <>
```

```r
lazy_length <- function(llist, acc = 0)
  cases(llist(),
        NIL -> acc,
        CONS(., cdr) -> lazy_length(cdr, acc + 1))

lazy_length(x)
```

```
## [1] 5
```

```r
lazy_length(y)
```

```
## [1] 2
```

```r
z <- delay_cons(make_noise(5), delay_cons(make_noise(6), lazy_nil))
lazy_length(z)
```

```
## I see 5 
## I see 6
```

```
## [1] 2
```

```r
lazy_length(z)
```

```
## [1] 2
```

```r
lazy_concat <- function(l1, l2) {
  cases(l1(),
        NIL -> l2,
        CONS(car, cdr) -> delay_cons(car, lazy_concat(cdr, l2)))
}

y <- delay_cons(make_noise(1), delay_cons(make_noise(2), lazy_nil))
z <- delay_cons(make_noise(5), delay_cons(make_noise(6), lazy_nil))

lazy_concat(y, z)
```

```
## I see 1
```

```
## I see 2 
## 1 :: <...>
```

```r
lazy_concat(y, z)
```

```
## 1 :: <...>
```

```r
y <- delay_cons(make_noise(1), delay_cons(make_noise(2), lazy_nil))
lazy_length(y)
```

```
## I see 1 
## I see 2
```

```
## [1] 2
```

```r
lazy_concat(y, z)
```

```
## 1 :: <...>
```

```r
lazy_to_llist(y)
```

```
## 1 :: 2 :: []
```

```r
lazy_to_llist(z)
```

```
## I see 5 
## I see 6
```

```
## 5 :: 6 :: []
```

```r
lazy_to_llist(lazy_concat(y, z))
```

```
## 1 :: 2 :: 5 :: 6 :: []
```

```r
lazy_reverse <- function(lazy, acc = lazy_nil)
  cases(lazy(),
        NIL -> acc,
        CONS(car, cdr) -> lazy_reverse(cdr, lazy_cons(car, acc)))

lazy_to_llist(x)
```

```
## 5 :: 4 :: 3 :: 2 :: 1 :: []
```

```r
lazy_to_llist(lazy_reverse(x))
```

```
## 1 :: 2 :: 3 :: 4 :: 5 :: []
```

```r
y <- delay_cons(make_noise(1), delay_cons(make_noise(2), lazy_nil))
lazy_reverse(y)
```

```
## I see 1 
## I see 2
```

```
## 2 :: <...>
```

```r
y <- delay_cons(make_noise(1), delay_cons(make_noise(2), lazy_nil))
z <- delay_cons(make_noise(6), delay_cons(make_noise(4), lazy_nil))
yy <- lazy_concat(y, lazy_reverse(z))
```

```
## I see 1
```

```r
lazy_to_llist(yy)
```

```
## I see 2 
## I see 6 
## I see 4
```

```
## 1 :: 2 :: 4 :: 6 :: []
```

```r
lazy_to_llist(yy)
```

```
## 1 :: 2 :: 4 :: 6 :: []
```

