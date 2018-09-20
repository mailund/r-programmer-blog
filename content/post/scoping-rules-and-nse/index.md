+++
title = "Scoping Rules and NSE"
date = 2018-09-20T05:00:15+02:00
tags = ["scope-rules"]
categories = ["Non-standard evaluation"]
draft = true
+++

Earlier this week, I wrote some tweets about how you have to be careful about scopes when you do non-standard evaluation. I cover this in both [*Metaprogramming in R*](https://amzn.to/2QHONDT) and [*Domain-Specific Languages in R*](https://amzn.to/2QHMNLL), but this tweet

{{< tweet 1041563992332881920 >}}

made me write about it again—only this time in a twitter thread.

Well, I say thread—I don't actually know how to do that, it seams; I just replied to the tweet a bunch of times and apparently that doesn't make a thread, it therefore my reply was hard to read. This is apparently where I went wrong

{{< tweet 1041815478493229061 >}}

Anyway, the first tweet links to [this page](https://github.com/WinVector/wrapr/blob/master/extras/MacrosInR.md) that contains a list of tools for implementing "macros" in R. This just means "tools for substituting expressions into other expressions" (preferably with some control over where they are put).[^macros] If you evaluate those expressions after the substitution, either right away or at some later time, it is also called *non-standard evaluation*. Not surprisingly, it is called that because it differs (at least it can differ) from standard evaluation where you simply have an expression and evaluate it.

[^macros]: I don't like the term macro here, because to me it sounds like something that would happen at compile time (which in R would be when you translate code into bytecode). This doesn't happen. There is no way (that I am aware of) to implement your own syntactic sugar that doesn't involve evaluating code at runtime.

The motivation for the [overview on macro methods](https://github.com/WinVector/wrapr/blob/master/extras/MacrosInR.md) was apparently that a paper on [the `wrapr` package](https://cran.r-project.org/web/packages/wrapr/) was rejected because it didn't compare the package with quasi-quotation from [`rlang`](https://cran.r-project.org/web/packages/rlang/). I might be partially responsible for this, since I reviewed the paper, but I didn't complain about the lack of comparison—I complained that `wrapr` doesn't deal with scopes (which `rlang` does), and that this makes `wrapr`'s `let` function very risky to use. You can *very* easily write a function that seems to work but contains subtle errors.

{{< tweet 1041567698239606785 >}}
{{< tweet 1041677761130229761 >}}

Since I didn't manage to make my tweets into a proper thread, so they would be easy to read, I will try to repeat it here. I can add a few things here, now that I have a whole post to work with, but I cannot get around all the interesting scope and NSE topics I would like to. For that, I will send you to my books, or return to those topics at a later time.

Before I get started, though, I once more want to stress that *this is not an attack on wrapr::let!* The issues with scope are there for pretty much [all tools that manipulate expressions](https://github.com/WinVector/wrapr/blob/master/extras/MacrosInR.md). The `rlang` package has "quosures"—expressions plus scopes—that alleviates many of the issues. This is the reason I prefer it over the others. If you do not explicitly handle scopes, you are likely to get into trouble with non-standard evaluation. Regardless of how you implement it.

I am simplifying a few things below to make the explanation easier; I am not describing what R *actually* does, but how it *conceptually* works with expressions and scopes. There are more details in it, but those are not relevant for this topic.

## The rules for expressions and evaluation

Whenever you write an expression in R, you create an expression object, an abstract syntax tree if you will, and then evaluates it.


```r
x <- 2 ; y <- 1 ; z <- 3
x * (y + z)
```

```
## [1] 8
```

You do not *have* to evaluate it, though. You can avoid this by *quoting* the expression


```r
quote(x * (y + z))
```

```
## x * (y + z)
```

This gives you the abstract syntax tree instead of the result of evaluating it.


```r
expr <- quote(x * (y + z))
class(expr)
```

```
## [1] "call"
```

In this particular case, it says that the syntax tree is a *call*. It is, because `*` is a function and that is what we are calling at the outermost level. There are other kinds an expression can be, e.g. constants and variables, but for this post that doesn't matter. What matters is that you can create non-evaluated (quoted) expressions.

That, alone, isn't that interesting. The interesting part is that you can:

1. Evaluate expressions later, in alternative scopes,
2. You can manipulate expressions and modify them before you evaluate them.

You evaluate an expression using the `eval` function


```r
eval(expr)
```

```
## [1] 8
```

and you can modify it in several ways; one way is using the built-in `substitute` function


```r
expr2 <- substitute(x * (y + z), list(x = 42))
expr2
```

```
## 42 * (y + z)
```

```r
eval(expr2)
```

```
## [1] 168
```


```r
set.seed(12345)

# Data:
d1 <- data.frame(x = rnorm(5), y = rnorm(5))
d2 <- data.frame(a = rnorm(5), b = rnorm(5))

# Not unreasonable usage:
summary(lm(y ~ x, data = d1))[["residuals"]]
```

```
##           1           2           3           4           5 
## -1.19510172  1.28778546  0.15138692  0.04667528 -0.29074594
```

```r
summary(lm(b ~ a, data = d2))[["residuals"]]
```

```
##          1          2          3          4          5 
##  0.3655564 -0.3493650 -0.5340553  0.9946969 -0.4768330
```

```r
xx <- rnorm(5) # for partial over-scoping
summary(lm(y ~ xx, data = d1))[["residuals"]]
```

```
##          1          2          3          4          5 
## -1.3927303  0.9882521  0.2902905  0.3724643 -0.2582766
```

```r
summary(lm(b ~ xx, data = d2))[["residuals"]]
```

```
##          1          2          3          4          5 
##  0.9484049 -0.5472260 -0.6373186  0.5359077 -0.2997679
```

```r
# Parameterise:
lm_prop <- function(x, y, d, prop) {
    m <- lm(y ~ x, data = d)
    summary(m)[[prop]]
}
lm_prop(x, y, d1, "residuals")
```

```
##           1           2           3           4           5 
## -1.19510172  1.28778546  0.15138692  0.04667528 -0.29074594
```

```r
# lm_prop(a, b, d2, "residuals")
# -> Error: a and b do not exist; we need NSE for this

library(wrapr)
```

```
## Error in library(wrapr): there is no package called 'wrapr'
```

```r
lm_prop2 <- function(x, y, d, prop, eval) {
    let(c(x = x, y = y, prop = prop),
        summary(lm(y ~ x, data = d))$prop,
        eval = eval)
}

# Complete overscoping
lm_prop2("x", "y", d1, "residuals", eval = FALSE)
```

```
## Error in let(c(x = x, y = y, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
summary(lm(y ~ x, data = d1))$residuals
```

```
##           1           2           3           4           5 
## -1.19510172  1.28778546  0.15138692  0.04667528 -0.29074594
```

```r
lm_prop2("x", "y", d1, "residuals", eval = TRUE)
```

```
## Error in let(c(x = x, y = y, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
# Partial overscoping
lm_prop2("xx", "y", d1, "residuals", eval = FALSE)
```

```
## Error in let(c(x = x, y = y, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
lm_prop2("xx", "y", d1, "residuals", eval = TRUE)
```

```
## Error in let(c(x = x, y = y, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
summary(lm(y ~ xx, data = d1))$residuals
```

```
##          1          2          3          4          5 
## -1.3927303  0.9882521  0.2902905  0.3724643 -0.2582766
```

```r
# Complete overscoping
lm_prop2("a", "b", d2, "residuals", eval = FALSE)
```

```
## Error in let(c(x = x, y = y, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
summary(lm(b ~ a, data = d2))$residuals
```

```
##          1          2          3          4          5 
##  0.3655564 -0.3493650 -0.5340553  0.9946969 -0.4768330
```

```r
lm_prop2("a", "b", d2, "residuals", eval = TRUE)
```

```
## Error in let(c(x = x, y = y, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
# Partial overscoping
lm_prop2("xx", "b", d2, "residuals", eval = FALSE)
```

```
## Error in let(c(x = x, y = y, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
summary(lm(b ~ xx, data = d2))$residuals
```

```
##          1          2          3          4          5 
##  0.9484049 -0.5472260 -0.6373186  0.5359077 -0.2997679
```

```r
lm_prop2("xx", "b", d2, "residuals", eval = TRUE)
```

```
## Error in let(c(x = x, y = y, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
# -> Works as intended!

# What if I used a different variable for the partial
# overscoping -- that should also work
x <- a <- xx
lm_prop2("a", "y", d1, "residuals", eval = FALSE)
```

```
## Error in let(c(x = x, y = y, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
summary(lm(y ~ a, data = d1))$residuals
```

```
##          1          2          3          4          5 
## -1.3927303  0.9882521  0.2902905  0.3724643 -0.2582766
```

```r
lm_prop2("a", "y", d1, "residuals", eval = TRUE)
```

```
## Error in let(c(x = x, y = y, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
lm_prop2("x", "b", d2, "residuals", eval = FALSE)
```

```
## Error in let(c(x = x, y = y, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
summary(lm(b ~ x, data = d2))$residuals
```

```
##          1          2          3          4          5 
##  0.9484049 -0.5472260 -0.6373186  0.5359077 -0.2997679
```

```r
# lm_prop2("x", "b", d2, "residuals", eval = TRUE)
# -> Error: in expression, x is the *string* "x"
#    At least we get an error

# Fix: don't substitute with the same name?
lm_prop3 <- function(a, b, d, prop, eval) {
    let(c(x = a, y = b, prop = prop),
        summary(lm(y ~ x, data = d))$prop,
        eval = eval)
}
lm_prop3("x", "b", d2, "residuals", eval = FALSE)
```

```
## Error in let(c(x = a, y = b, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
summary(lm(b ~ x, data = d2))$residuals
```

```
##          1          2          3          4          5 
##  0.9484049 -0.5472260 -0.6373186  0.5359077 -0.2997679
```

```r
lm_prop3("x", "b", d2, "residuals", eval = TRUE)
```

```
## Error in let(c(x = a, y = b, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
lm_prop3("a", "y",  d1, "residuals", eval = FALSE)
```

```
## Error in let(c(x = a, y = b, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
summary(lm(y ~ a, data = d1))$residuals
```

```
##          1          2          3          4          5 
## -1.3927303  0.9882521  0.2902905  0.3724643 -0.2582766
```

```r
# lm_prop3("a", "y",  d1, "residuals", eval = TRUE)
# -> Error: even if we do not use it to substitute,
#    then a is still a local variable.
#    We *cannot* call this function with names
#    that can be local variables!


# Avoid any conflict btw args and local variables
lm_prop4 <- function(.a, .b, d, prop, eval) {
    let(c(x = .a, y = .b, prop = prop),
        summary(lm(y ~ x, data = d))$prop,
        eval = eval)
}
lm_prop4("a", "y",  d1, "residuals", eval = FALSE)
```

```
## Error in let(c(x = .a, y = .b, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
summary(lm(y ~ a, data = d1))$residuals
```

```
##          1          2          3          4          5 
## -1.3927303  0.9882521  0.2902905  0.3724643 -0.2582766
```

```r
lm_prop4("a", "y",  d1, "residuals", eval = TRUE)
```

```
## Error in let(c(x = .a, y = .b, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
lm_prop4("x", "b", d2, "residuals", eval = FALSE)
```

```
## Error in let(c(x = .a, y = .b, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
summary(lm(b ~ x, data = d2))$residuals
```

```
##          1          2          3          4          5 
##  0.9484049 -0.5472260 -0.6373186  0.5359077 -0.2997679
```

```r
lm_prop4("x", "b", d2, "residuals", eval = TRUE)
```

```
## Error in let(c(x = .a, y = .b, prop = prop), summary(lm(y ~ x, data = d))$prop, : could not find function "let"
```

```r
# All is well!

# What if we had done this?
lm_prop5 <- function(.a, .b, .d, prop, eval) {
    let(c(x = .a, y = .b, d = .d, prop = prop),
        summary(lm(y ~ x, data = d))$prop,
        eval = eval)
}
lm_prop5("a", "y",  "d1", "residuals", eval = FALSE)
```

```
## Error in let(c(x = .a, y = .b, d = .d, prop = prop), summary(lm(y ~ x, : could not find function "let"
```

```r
summary(lm(y ~ a, data = d1))$residuals
```

```
##          1          2          3          4          5 
## -1.3927303  0.9882521  0.2902905  0.3724643 -0.2582766
```

```r
lm_prop5("a", "y",  "d1", "residuals", eval = TRUE)
```

```
## Error in let(c(x = .a, y = .b, d = .d, prop = prop), summary(lm(y ~ x, : could not find function "let"
```

```r
lm_prop5("x", "b",  "d2", "residuals", eval = FALSE)
```

```
## Error in let(c(x = .a, y = .b, d = .d, prop = prop), summary(lm(y ~ x, : could not find function "let"
```

```r
summary(lm(b ~ x, data = d2))$residuals
```

```
##          1          2          3          4          5 
##  0.9484049 -0.5472260 -0.6373186  0.5359077 -0.2997679
```

```r
lm_prop5("x", "b",  "d2", "residuals", eval = TRUE)
```

```
## Error in let(c(x = .a, y = .b, d = .d, prop = prop), summary(lm(y ~ x, : could not find function "let"
```

```r
# Great!?

indirect <- function(xx, yy, eval) {
    d <- data.frame(x = xx, y = yy)
    lm_prop5("x", "y", "d", "residuals", eval = eval)
}

aa <- rnorm(5) ; bb <- rnorm(5)
summary(lm(bb ~ aa))$residuals
```

```
##          1          2          3          4          5 
## -0.2855751  0.5968646  0.6913960  0.2728369 -1.2755224
```

```r
indirect(aa, bb, eval = FALSE)
```

```
## Error in let(c(x = .a, y = .b, d = .d, prop = prop), summary(lm(y ~ x, : could not find function "let"
```

```r
indirect(aa, bb, eval = TRUE)
```

```
## Error in let(c(x = .a, y = .b, d = .d, prop = prop), summary(lm(y ~ x, : could not find function "let"
```

```r
# -> Error: d isn't known (it is in the wrong scope)

d <- d1 # what would have happened if we had a global d?
indirect(aa, bb, eval = TRUE) # no error, but wrong result!
```

```
## Error in let(c(x = .a, y = .b, d = .d, prop = prop), summary(lm(y ~ x, : could not find function "let"
```

```r
# You get:
summary(lm(y ~ x, data = d1))$residuals
```

```
##           1           2           3           4           5 
## -1.19510172  1.28778546  0.15138692  0.04667528 -0.29074594
```

```r
# You expected:
summary(lm(bb ~ aa))$residuals
```

```
##          1          2          3          4          5 
## -0.2855751  0.5968646  0.6913960  0.2728369 -1.2755224
```

```r
# The problem is that the d variable is found in the
# global scope and not the calling scope. Fix:
lm_prop6 <- function(.a, .b, .d, .prop, eval) {
    let(c(x = .a, y = .b, d = .d, prop = .prop),
        summary(lm(y ~ x, data = d))$prop,
        envir = parent.frame(),
        eval = eval)
}
indirect2 <- function(xx, yy, eval) {
    d <- data.frame(x = xx, y = yy)
    lm_prop6("x", "y", "d", "residuals", eval = eval)
}
summary(lm(bb ~ aa))$residuals
```

```
##          1          2          3          4          5 
## -0.2855751  0.5968646  0.6913960  0.2728369 -1.2755224
```

```r
indirect2(aa, bb, eval = TRUE) # Fixed!
```

```
## Error in let(c(x = .a, y = .b, d = .d, prop = .prop), summary(lm(y ~ x, : could not find function "let"
```

```r
## New example...
rm("a", "x", "aa", "bb", "xx")
model_prop <- function(.x, .y, .d, .prop) {
    let(c(x = .x, y = .y, d = .d, prop = .prop),
        summary(lm(y ~ x, data = d))$prop,
        envir = parent.frame())
}
# This works both with global variables
# and variables in the calling scope

# Now let us use it...
set.seed(1234)
ylen <- with(d1, length(y))
.z <- rnorm(ylen)
list(xy = model_prop("x", "y", "d1", "r.squared"),
     xz = model_prop("x", ".z", "d1", "r.squared"))
```

```
## Error in let(c(x = .x, y = .y, d = .d, prop = .prop), summary(lm(y ~ x, : could not find function "let"
```

```r
# Parameterise
rm("ylen", ".z")
xyz <- function(.x, .y, .d, .prop) {
    let(c(d = .d, x = .x, y = .y),
        {
            ylen <- with(d, length(y))
            .z <- rnorm(ylen)
            # NB: don't mess up the parameters here
            # You cannot use the substituted and you
            # have to use ".z" as string
            list(xy = model_prop(.x, .y, .d, .prop),
                 xz = model_prop(.x, ".z", .d, .prop))
        })
}

# works with overscoping
set.seed(1234) ; xyz("x", "y", "d1", "r.squared")
```

```
## Error in let(c(d = .d, x = .x, y = .y), {: could not find function "let"
```

```r
set.seed(1234) ; xyz("a", "b", "d2", "r.squared")
```

```
## Error in let(c(d = .d, x = .x, y = .y), {: could not find function "let"
```

```r
# works with global vars.
xx <- d1$x ; yy <- d1$y
set.seed(1234) ; xyz("xx", "yy", "d1", "r.squared")
```

```
## Error in let(c(d = .d, x = .x, y = .y), {: could not find function "let"
```

```r
set.seed(1234) ; xyz("xx", "yy", "d2", "r.squared")
```

```
## Error in let(c(d = .d, x = .x, y = .y), {: could not find function "let"
```

```r
# works with partial overscoping
set.seed(1234) ; xyz("xx", "y", "d1", "r.squared")
```

```
## Error in let(c(d = .d, x = .x, y = .y), {: could not find function "let"
```

```r
set.seed(1234) ; xyz("x", "yy", "d1", "r.squared")
```

```
## Error in let(c(d = .d, x = .x, y = .y), {: could not find function "let"
```

```r
set.seed(1234) ; xyz("xx", "b", "d2", "r.squared")
```

```
## Error in let(c(d = .d, x = .x, y = .y), {: could not find function "let"
```

```r
set.seed(1234) ; xyz("a", "yy", "d2", "r.squared")
```

```
## Error in let(c(d = .d, x = .x, y = .y), {: could not find function "let"
```

```r
set.seed(1234) ; xyz("x", "y", "d1", "r.squared")
```

```
## Error in let(c(d = .d, x = .x, y = .y), {: could not find function "let"
```

```r
xyz_df <- function(d, prop) xyz("x", "y", "d", prop)
set.seed(1234) ; xyz_df(d1, "r.squared") 
```

```
## Error in let(c(d = .d, x = .x, y = .y), {: could not find function "let"
```

```r
# We get the same result, so this should be fine?!??
# Wrong, the function finds the global d; it doesn't use d1
set.seed(4321) ; d <- data.frame(x = rnorm(5), y = rnorm(5))

set.seed(1234) ; xyz_df(d1, "r.squared") 
```

```
## Error in let(c(d = .d, x = .x, y = .y), {: could not find function "let"
```

```r
set.seed(4123) ; d <- data.frame(x = rnorm(5), y = rnorm(5))
set.seed(1234) ; xyz_df(d1, "r.squared") 
```

```
## Error in let(c(d = .d, x = .x, y = .y), {: could not find function "let"
```

```r
# Oops, we use the global d and not d1!


xyz <- function(.x, .y, .d, .prop) {
    let(c(d = .d, x = .x, y = .y),
        {
            ylen <- with(d, length(y))
            .z <- rnorm(ylen)
            # NB: don't mess up the parameters here
            # You cannot use the substituted and you
            # have to use ".z" as string
            list(xy = model_prop(.x, .y, .d, .prop),
                 xz = model_prop(.x, ".z", .d, .prop))
        },
        envir = parent.frame())
}
# set.seed(1234) ; xyz_df(d1, "r.squared") 
# -> Error: now it doesn't know .x (fair enough, it is a local var)


xyz <- function(.x, .y, .d, .prop) {
    # we need to chain environments...
    my_env <- environment()
    parent.env(my_env) <- parent.frame()
    let(c(d = .d, x = .x, y = .y),
        {
            ylen <- with(d, length(y))
            .z <- rnorm(ylen)
            # NB: don't mess up the parameters here
            # You cannot use the substituted and you
            # have to use ".z" as string
            list(xy = model_prop(.x, .y, .d, .prop),
                 xz = model_prop(.x, ".z", .d, .prop))
        },
        envir = my_env)
}
set.seed(1234) ; xyz_df(d1, "r.squared") 
```

```
## Error in let(c(d = .d, x = .x, y = .y), {: could not find function "let"
```

```r
set.seed(1234) ; xyz("x", "y", "d1", "r.squared")
```

```
## Error in let(c(d = .d, x = .x, y = .y), {: could not find function "let"
```


<hr/>
<small>If you liked what you read, and want more like it, consider supporting me at [Patreon](https://www.patreon.com/mailund).</small>
<hr/>

