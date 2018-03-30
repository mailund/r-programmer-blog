---
title: “Optional” types using pmatch
author: Thomas Mailund
date: '2018-03-30'
slug: optional-types-using-pmatch
categories:
  - DSL
  - Pattern-matching
tags:
  - pmatch
---



Some programming languages, e.g. Swift, have special "optional" types. These are types the represent elements that either contain a value of some other type or contain nothing at all. It is a way of computing with the possibility that some operations cannot be done and then propagating that along in the computations.

We can use [`pmatch`](https://mailund.github.io/pmatch/) to implement something similar in R. I will use three types instead of two, to represent no value, `NONE`, some value, `VALUE(val)`, or some error `ERROR(err)`:


```r
library(pmatch)
OPT := NONE | VALUE(val) | ERROR(err)
```

We can now define a function that catches exceptions and translate them into `ERROR()` objects:


```r
try <- function(expr) {
    rlang::enquo(expr)
    tryCatch(VALUE(rlang::eval_tidy(expr)), 
             error = function(e) ERROR(e))
}
```

With this function the control flow when we want to compute something that might go wrong can be made a bit simpler. We no longer need a callback error handler; instead we can inspect the value returned by `try` in a `cases` call:


```r
cases(try(42),
      VALUE(val) -> val,
      ERROR(err) -> err,
      NONE -> "NOTHING")
```

```
## [1] 42
```


```r
cases(try(x + 42), # x isn't defined...
      VALUE(val) -> val,
      ERROR(err) -> err,
      NONE -> "NOTHING")
```

```
## <simpleError in rlang::eval_tidy(expr): objekt 'x' blev ikke fundet>
```

To extract the value of an expression after we have computed on optional values we can define this function:


```r
value <- function(x) {
    quoted_x <- rlang::enexpr(x)
    cases(x,
          VALUE(val) -> val,
          . -> stop(simpleError(
                paste(deparse(quoted_x), " is not a value."), 
              call = quoted_x
        )))
}
    

value(try(42))
```

```
## [1] 42
```

```r
value(try(42 + x))
```

```
## Error in try(42 + x): try(42 + x)  is not a value.
```

## Computing with optional values

Computing on optional values is more interesting if we can make it relatively transparent that this is what we are doing. For arithmetic expressions we can do this by defining operations on these types. A sensible way is to return errors if we see those, then `NONE` if we see one of those, and otherwise use `VALUE`:


```r
Ops.OPT <- function(e1, e2) {
    cases(..(e1, e2),
          ..(ERROR(err), .)        -> ERROR(err),
          ..(., ERROR(err))        -> ERROR(err),
          ..(NONE, .)              -> NONE,
          ..(., NONE)              -> NONE,
          ..(VALUE(v1), VALUE(v2)) -> VALUE(do.call(.Generic, list(v1, v2))),
          ..(VALUE(v1), v2)        -> VALUE(do.call(.Generic, list(v1, v2))),
          ..(v1, VALUE(v2))        -> VALUE(do.call(.Generic, list(v1, v2)))
    )
}
```

The last two cases here handles when we combine an optional value with a value from the underlying type. Because of the last two cases we do not need to explicitly translate a value into a `VALUE()`. With this group function defined we can use optional values in expressions.


```r
VALUE(12) + VALUE(6)
```

```
## VALUE(val = 18)
```

```r
NONE + VALUE(6)
```

```
## NONE
```

```r
ERROR("foo") + NONE
```

```
## ERROR(err = foo)
```

```r
VALUE(12) + ERROR("bar")
```

```
## ERROR(err = bar)
```

```r
VALUE(12) + 12
```

```
## VALUE(val = 24)
```

```r
12 + NONE
```

```
## NONE
```

```r
12 + try(42 + x)
```

```
## ERROR(err = Error in rlang::eval_tidy(expr): objekt 'x' blev ikke fundet
## )
```


For mathematical functions, such as `log` or `exp`, we can also define versions for optional types:


```r
Math.OPT <- function(x, ...) {
    cases(x,
          ERROR(err) -> ERROR(err),
          NONE       -> NONE,
          VALUE(v)   -> do.call(.Generic, list(x)),
          v          -> do.call(.Generic, list(x))
    )
}
```


```r
log(ERROR("foo"))
```

```
## ERROR(err = foo)
```

```r
exp(NONE)
```

```
## NONE
```


I'm pretty confident that you can also add some more to this, so you can wrap more complicated computations and propagate `NONE` and `ERROR()`. I will experiment with that later.

I also strongly suspect that someone who understands monads better than I do can make an even smarter implementation. If so, I would love to hear about it.
