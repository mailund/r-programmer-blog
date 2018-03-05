---
title: Evaluating dynprog expressions
author: Thomas Mailund
date: '2018-03-04'
slug: evaluating-dynprog-expressions
categories:
  - DSL
  - Metaprogramming
tags:
  - dynamic-programming
  - dynprog
---

I think I now have a complete implementation of the dynamic programming DSL [I wrote about the other day](https://mailund.github.io/r-programmer-blog/2018/03/03/designing-a-dsl-for-dynamic-programming/). You can install it from [the GitHub repository](https://github.com/mailund/dynprog) if you want to experiment with it.


```r
devtools::install_github("mailund/dynprog")
library(dynprog)
```


The syntax for computing a table of factorial values now looks like this:


```r
fact <- {
  fact[n] <- n * fact[n - 1] ? n > 1
  fact[n] <- 1               ? n <= 1
} %where% {n <- 1:8}
fact
```

```
## [1]     1     2     6    24   120   720  5040 40320
```

For computing the [edit distance](https://en.wikipedia.org/wiki/Edit_distance) you can write a recursion like this:


```r
x <- strsplit("abd", "")[[1]]
y <- strsplit("abbd", "")[[1]]
edit <- {
  edit[1,j] <- j - 1
  edit[i,1] <- i - 1
  edit[i,j] <- min(
      edit[i - 1,j] + 1,
      edit[i,j - 1] + 1,
      edit[i - 1,j - 1] + (x[i - 1] != y[j - 1])
  )   ? i > 1 && j > 1
} %where% {
    i <- 1:(length(x) + 1)
    j <- 1:(length(y) + 1)
}
edit
```

```
##      [,1] [,2] [,3] [,4] [,5]
## [1,]    0    1    2    3    4
## [2,]    1    0    1    2    3
## [3,]    2    1    0    1    2
## [4,]    3    2    1    1    1
```

The syntax is a little different from what I presented [in the previous post](https://mailund.github.io/r-programmer-blog/2018/03/03/designing-a-dsl-for-dynamic-programming/). I hadn’t thought completely through how I should represent strings, and I’m not sure this is the easiest way to get strings represented  as vectors of characters, but, hey, it works, so this is what I have now.

I will describe the design in details in [Domain Specific Languages in R](http://amzn.to/2FO5MiQ), but before I write the chapter for this DSL, I would love to get some feedback. So here, I will describe the current design.

## Parsing expressions

All the magic in parsing the language is done by the `%where%` operator. It is an infix operator, so it takes two arguments. The first is the recursion equations and the second the ranges the dynamic programming algorithm should iterate over. I parse these separately before I evaluate anything.

```
`%where%` <- function(recursion, ranges) {
    parsed <- list(
        recursions = parse_recursion(rlang::enquo(recursion)),
        ranges = parse_ranges(rlang::enquo(ranges))
    )
    eval_dynprog(parsed)
}
```

I translate both `recursion` and `ranges`—the two arguments to the operator—into quosures so I have their environment to evaluate the expressions in. For `parse_ranges`, I evaluate the expressions in the ranges specification and create a list that has one item per range-iterator; each such item is a vector of the indices for the range-iterator.




```r
parse_ranges(rlang::quo({n <- 1:8}))
```

```
## $n
## [1] 1 2 3 4 5 6 7 8
```

```r
parse_ranges(rlang::quo({
    i <- 1:(length(x) + 1)
    j <- 1:(length(y) + 1)
}))
```

```
## $i
## [1] 1 2 3 4
## 
## $j
## [1] 1 2 3 4 5
```




The recursion-equations I parse into three lists, one for the pattern on the left-hand-side of the assignments, one for the conditions following `?`, and one for the actual recursions. I also store the environment of the expression. I don’t need to do this for the ranges because I evaluate the expressions there as part of the parsing, but for the recursions I need to remember where to evaluate expressions.


```r
parse_recursion(rlang::quo({
  fact[n] <- n * fact[n - 1] ? n > 1
  fact[n] <- 1               ? n <= 1
}))
```

```
## $recursion_env
## <environment: R_GlobalEnv>
## 
## $patterns
## $patterns[[1]]
## fact[n]
## 
## $patterns[[2]]
## fact[n]
## 
## 
## $conditions
## $conditions[[1]]
## n > 1
## 
## $conditions[[2]]
## n <= 1
## 
## 
## $recursions
## $recursions[[1]]
## n * fact[n - 1]
## 
## $recursions[[2]]
## [1] 1
```


```r
parse_recursion(rlang::quo({
  edit[1,j] <- j - 1
  edit[i,1] <- i - 1
  edit[i,j] <- min(
      edit[i - 1,j] + 1,
      edit[i,j - 1] + 1,
      edit[i - 1,j - 1] + (x[i - 1] != y[j - 1])
  ) ? i > 1 && j > 1
}))
```

```
## $recursion_env
## <environment: R_GlobalEnv>
## 
## $patterns
## $patterns[[1]]
## edit[1, j]
## 
## $patterns[[2]]
## edit[i, 1]
## 
## $patterns[[3]]
## edit[i, j]
## 
## 
## $conditions
## $conditions[[1]]
## [1] TRUE
## 
## $conditions[[2]]
## [1] TRUE
## 
## $conditions[[3]]
## i > 1 && j > 1
## 
## 
## $recursions
## $recursions[[1]]
## j - 1
## 
## $recursions[[2]]
## i - 1
## 
## $recursions[[3]]
## min(edit[i - 1, j] + 1, edit[i, j - 1] + 1, edit[i - 1, j - 1] + 
##     (x[i - 1] != y[j - 1]))
```

## Evaluating expressions

As I explained earlier, I want the semantics to be this: the expression should iterate over the ranges, in the order they are provided, and for each combination of range-iterators, match the index variables against the patterns and conditions in the order these are provided. For the first pattern/condition combination that evaluates to `TRUE`, I will evaluate the recursion expression and assign the value into the dynamic programming table.

To achieve this, I first have to construct code for testing patterns and expressions. The top-level evaluation function looks like this:


```r
eval_dynprog <- function(dynprog) {
    conditions <- make_pattern_tests(
        dynprog$recursion$patterns,
        Map(as.symbol, names(dynprog$ranges))
    )
    for (i in seq_along(conditions)) {
        conditions[[i]] <- rlang::call2(
            "&&", dynprog$recursion$conditions[[i]], conditions[[i]]
        )
    }
    eval_recursion(
        get_table_name(dynprog$recursions$patterns),
        update_expr(conditions, dynprog$recursions$recursions),
        dynprog$ranges,
        dynprog$recursions$recursion_env
    )
}
```

I construct the checks for matching patterns and conditions in the `make_pattern_tests` function and the `for`-loop that follows it. The `make_pattern_tests` builds expressions for checking if indices matches the pattern in the recursion specification. The conditions are already expressions in the DSL, so I don’t need to do anything with those, but I combine patterns and conditions by wrapping them in `&&` calls, ensuring that a condition is only true if both the `?`-conditions and patterns are true.

The actual expression evaluation is done in this function:


```r
eval_recursion <- function(tbl_name, update_expr, ranges, eval_env) {
    loop <- rlang::expr({
        combs <- do.call(expand.grid, ranges)
        rlang::UQ(tbl_name) <- vector("numeric", length = nrow(combs))
        dim(rlang::UQ(tbl_name)) <- Map(length, ranges)
        for (row in seq_along(rlang::UQ(tbl_name))) {
            rlang::UQ(tbl_name)[row] <- with(combs[row, , drop = FALSE], {
                rlang::UQ(update_expr)
            })
        }
        rlang::UQ(tbl_name)
    })
    eval(loop, envir = rlang::env_clone(environment(), eval_env))
}
```

This will look a bit complicated if you are not familiar with `rlang` and quasi-quotation (and if you are not, may I recommend [this excellent book](http://amzn.to/2FO5MiQ) where you can learn about it?)

It will be a bit easier to understand if we see the expression, that we construct inside it, expanded. 



First, I will just construct the parsed result we would get by parsing the edit-distance expression:


```r
recursions <- parse_recursion(rlang::quo({
  edit[1,j] <- j - 1
  edit[i,1] <- i - 1
  edit[i,j] <- min(
      edit[i - 1,j] + 1,
      edit[i,j - 1] + 1,
      edit[i - 1,j - 1] + (x[i - 1] != y[j - 1])
  ) ? i > 1 && j > 1
}))
ranges <- parse_ranges(rlang::quo({
    i <- 1:(length(x) + 1)
    j <- 1:(length(y) + 1)
}))
dynprog <- list(
    recursions = recursions,
    ranges = ranges
)
```

The manipulations of `conditions` in the evaluation function first creates pattern-matching expressions:


```r
conditions <- make_pattern_tests(
    dynprog$recursion$patterns,
    Map(as.symbol, names(dynprog$ranges))
)
conditions
```

```
## [[1]]
## all(1 == i, j == j)
## 
## [[2]]
## all(i == i, 1 == j)
## 
## [[3]]
## all(i == i, j == j)
```

I have kept this very simple. The variables that are part of the pattern-expression in the recursions are simply matched against the variables specified in the ranges. I get silly stuff like `i == i`, but I’m okay with that. This will just evaluate to `TRUE`. The interesting part is when I have to match an index against some value—either a constant, as in the cases here, or an expression to be evaluated. I either case, I want to test if the range variables matches the values, and the `all()` function combined with the simple comparisons will do that, as long as I evaluate the expressions in the right scope (which I will ensure later).

For the `?` conditions, I either have `TRUE` or some expression in the `conditions` list I get from the parse. I simply combine those with the pattern-conditions:


```r
for (i in seq_along(conditions)) {
    conditions[[i]] <- rlang::call2(
        "&&", dynprog$recursion$conditions[[i]], conditions[[i]]
    )
}
conditions
```

```
## [[1]]
## TRUE && all(1 == i, j == j)
## 
## [[2]]
## TRUE && all(i == i, 1 == j)
## 
## [[3]]
## i > 1 && j > 1 && all(i == i, j == j)
```

The final step in `eval_dynprog` is this expression:

```r
    eval_recursion(
        get_table_name(dynprog$recursions$patterns),
        update_expr(conditions, dynprog$recursions$recursions),
        dynprog$ranges,
        dynprog$recursions$recursion_env
    )
```

The `get_table_name` does exactly what you would expect. It extracts the name of the dynamic programming table from the patterns. In the earlier syntax I had, you would explicitly provide the table name as part of the `%with%` expression, but now I just get it from the patterns.

The `update_expr` combines the patterns- and `?`-conditions we just constructed with the values we want to evaluate when conditions are met. The function translates these pieces of information into a sequence of `if-else`-statements.


```r
update_expr(conditions, dynprog$recursions$recursions)
```

```
## if (TRUE && all(1 == i, j == j)) j - 1 else if (TRUE && all(i == 
##     i, 1 == j)) i - 1 else if (i > 1 && j > 1 && all(i == i, 
##     j == j)) min(edit[i - 1, j] + 1, edit[i, j - 1] + 1, edit[i - 
##     1, j - 1] + (x[i - 1] != y[j - 1]))
```

In `eval_recursion`, we insert this expression into the body of a loop:

```r
    loop <- rlang::expr({
        combs <- do.call(expand.grid, ranges)
        rlang::UQ(tbl_name) <- vector("numeric", length = nrow(combs))
        dim(rlang::UQ(tbl_name)) <- Map(length, ranges)
        for (row in seq_along(rlang::UQ(tbl_name))) {
            rlang::UQ(tbl_name)[row] <- with(combs[row, , drop = FALSE], {
                rlang::UQ(update_expr)
            })
        }
        rlang::UQ(tbl_name)
    })
```

The `rlang::UQ()`—in case you are not familiar with it—unquotes an expression and lets us insert it into the `rlang::expr` result. We use it to set the name of the table we create and to insert `udpate_expr` into the body of the loop.

I realise, as I write this, that it is a bit unfortunate that I have used the same name, `update_expr`, for the expression and the function that creates it. I will go back and fix this later.

Anyway, we can see what the `loop` expression will look like if we insert the `tbl_name` and `update_expr` expressions into it.


```r
tbl_name <- rlang::expr(edit)
update_expr <- update_expr(conditions, dynprog$recursions$recursions)
loop <- rlang::expr({
        combs <- do.call(expand.grid, ranges)
        rlang::UQ(tbl_name) <- vector("numeric", length = nrow(combs))
        dim(rlang::UQ(tbl_name)) <- Map(length, ranges)
        for (row in seq_along(rlang::UQ(tbl_name))) {
            rlang::UQ(tbl_name)[row] <- with(combs[row, , drop = FALSE], {
                rlang::UQ(update_expr)
            })
        }
        rlang::UQ(tbl_name)
})
loop
```

```
## {
##     combs <- do.call(expand.grid, ranges)
##     edit <- vector("numeric", length = nrow(combs))
##     dim(edit) <- Map(length, ranges)
##     for (row in seq_along(edit)) {
##         edit[row] <- with(combs[row, , drop = FALSE], {
##             if (TRUE && all(1 == i, j == j)) 
##                 j - 1
##             else if (TRUE && all(i == i, 1 == j)) 
##                 i - 1
##             else if (i > 1 && j > 1 && all(i == i, j == j)) 
##                 min(edit[i - 1, j] + 1, edit[i, j - 1] + 1, edit[i - 
##                   1, j - 1] + (x[i - 1] != y[j - 1]))
##         })
##     }
##     edit
## }
```

The `do.call` expression builds a table over all ranges combinations. 


```r
do.call(expand.grid, ranges)
```

```
##    i j
## 1  1 1
## 2  2 1
## 3  3 1
## 4  4 1
## 5  1 2
## 6  2 2
## 7  3 2
## 8  4 2
## 9  1 3
## 10 2 3
## 11 3 3
## 12 4 3
## 13 1 4
## 14 2 4
## 15 3 4
## 16 4 4
## 17 1 5
## 18 2 5
## 19 3 5
## 20 4 5
```

The dynamic programming table will have as many values as there are combinations of ranges indices, so we can construct it as a vector of that length. The dimensions of the table are given by the length of the ranges expressions, and that is what we get by this expression:


```r
Map(length, ranges)
```

```
## $i
## [1] 4
## 
## $j
## [1] 5
```

We do not iterate over the ranges using nested `for`-loops. That would require us to build expressions for the these loops. It is much easier to just iterate over the grid of combinations, which is what we do. When we then use the `with(combs[row,,drop=FALSE], ...)` expression, we automatically get values assigned to the range-index variables, and it is in this context we evaluate the `update_expr` expression.

Once we have constructed this loop-expression, we need to evaluate it, and here the only tricky thing is making sure that we evaluate it in the right scope.

I have used this expression for that:

```r
eval(loop, envir = rlang::env_clone(environment(), eval_env))
```

The `eval_env` is the environment we get from the recursion quosure, so that will contain the scope where the expressions are defined. I wrap that in another environment that includes the local environment of the `eval_recursion` function. I do this only to get the `ranges` variable set to the ranges I have parsed in the DSL. There might be a smarter way of doing this—if there is, I would love to hear it—but this works fine and is reasonably straightforward.

What do you guys think? Have I made it overly complicated or have I missed some cases that the current code doesn’t handle? I would love to hear from you; tweet me at [@ThomasMailund](https://twitter.com/ThomasMailund).
