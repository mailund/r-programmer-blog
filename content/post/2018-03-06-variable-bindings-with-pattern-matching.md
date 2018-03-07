---
title: Variable bindings with pattern matching
author: Thomas Mailund
date: '2018-03-06'
slug: variable-bindings-with-pattern-matching
categories:
  - Metaprogramming
  - DSL
  - Pattern-matching
tags:
  - pmatch
---

I just added a new feature to my [`pmatch` package](https://github.com/mailund/pmatch). You will need the development version to get it, until I make a new release, and I have a few more features planned before that.

```r
# install.packages("devtools")
devtools::install_github("mailund/pmatch")
```



This package implements Haskell- or ML-like pattern matching, and I showed some examples of it in my post on [tail-recursion optimisation](https://mailund.github.io/r-programmer-blog/2018/03/02/tailr--tail-recursion-optimisation/). The goal of the package was to make it easier to write more functional code in R—which is also the goal of the tail-recursion optimisation project I’m working on—but the features in `pmatch` also makes it easier to implement a variant of parallel/multiple-variable assignments.

What I mean by that term is the kind of assignments that in Python, for example, looks like this:

```python
x, y, z = 1, 2, 3
```

Here, we assign to all three variables, `x`, `y`, and `z`, as a single instruction, and if we assign values that refer to the parameters, we get the values *before* they are assigned to, so

```python
x, y, z = 1, 2, 3
x, y, z = z, x, y
```

leaves `x` with the value 3, `y` with the value 1, and `z` with the value 2. This, in contrast to

```python
x, y, z = 1, 2, 3
x = z
y = x
z = y
```

where the assignments are executed sequentially and all variables end up holding the value 3.

I have implemented this functionality before, in different ways, and I know that I am not the only one. With pattern-matching, though, it gets a little more exciting.

## The `bind` object and variable bindings

The entire implementation looks like this:


```r
bind <- structure(NA, class = "tailr_bind")

`[<-.tailr_bind` <- function(dummy, ..., value) {
    force(value)
    var_env <- rlang::caller_env()
    patterns <- eval(substitute(alist(...)))
    if (length(patterns) == 1) {
          value <- list(value)
    }

    for (i in seq_along(patterns)) {
        var_bindings <- test_pattern_(
            value[[i]],
            patterns[[i]], 
            eval_env = var_env
        )
        if (is.null(var_bindings)) {
            stop("error")
        }
        copy_env(from = var_bindings, to = var_env)
    }

    dummy
}
```

where I use this function to copy variables from one environment to another:


```r
copy_env <- function(from, to, names=ls(from, all.names = TRUE)) {
    mapply(
        assign, names, mget(names, from), list(to),
        SIMPLIFY = FALSE, USE.NAMES = FALSE
    )
    invisible(NULL)
}
```

The `bind` object only exists to give me a class where I can specialise the subscript operator so I can get syntax such as


```r
bind[x, y, z] <- 1:3
c(x, y, z)
```

```
## [1] 1 2 3
```

```r
bind[x, y, z] <- c(z, x, y)
c(x, y, z)
```

```
## [1] 3 1 2
```

The real work is done in the operator. Here, I simply iterate over the variables provided as indices in the subscript, and for each, I use `test_pattern_` to match the pattern against the appropriate value in the calling scope. I need the scope to be somewhere I can get access to constructors for the pattern matching to work. I do nothing to treat the values specially, so they are provided to the function as a promise that will be evaluated in the calling scope.

I explicitly `force` them to make sure that the values are evaluated before I start messing with the environment and updating variables. Strictly speaking,  this isn’t necessary—the promise will be evaluated the first time I invoke `value[[i]]` inside the loop—but I prefer to be explicit when it comes to lazy evaluation that might bite me at some later time. It is essential that the `value` promise is evaluated before I start assigning to variables. Otherwise, the assignments would look like the sequential version of the Python code. Because I evaluate all the values before the loop, when I call `force`, the assignments will occur in parallel.

The

```r
    if (length(patterns) == 1) {
          value <- list(value)
    }
```

statement might look a little odd, but it is needed when I match against values made from `pmatch` constructors. These are lists, and if there is only a single one provided, I make sure it is wrapped as a list with a single element so the indices in the loop will function correctly.

When you use the subscript operator in this way, make sure you return the dummy variable from the function. The assignment operator for subscripting will overwrite the variable that contains the dummy value with the return value from this function and we do not want to change the value of `bind`.

## Pattern matching and bindings

The reason I found it interesting to implement this type of variable assignments one more time is the combination with pattern matching. I can define something like a linked list:


```r
llist := NIL | CONS(car, cdr : llist)
L <- CONS(1, CONS(2, CONS(3, NIL)))
L
```

```
## CONS(car = 1, cdr = CONS(car = 2, cdr = CONS(car = 3, cdr = NIL)))
```

and then match against constructor-patterns to assign parts of a list to variables:


```r
bind[CONS(first, CONS(second, rest))] <- L
c(first, second)
```

```
## [1] 1 2
```

Similarly for binary trees:


```r
tree := L(elm : numeric) | T(left : tree, right : tree)
x <- T(T(L(1),L(2)), T(T(L(3),L(4)),L(5)))
x
```

```
## T(left = T(left = L(elm = 1), right = L(elm = 2)), right = T(left = T(left = L(elm = 3), right = L(elm = 4)), right = L(elm = 5)))
```


```r
bind[T(left, right)] <- x
left
```

```
## T(left = L(elm = 1), right = L(elm = 2))
```

```r
right
```

```
## T(left = T(left = L(elm = 3), right = L(elm = 4)), right = L(elm = 5))
```

```r
bind[T(L(one),L(two)), T(left2, L(five))] <- list(left, right)
c(one, two, five)
```

```
## [1] 1 2 5
```

Cool, right?
