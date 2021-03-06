---
title: Another approach to evaluating dynprog expressions
author: Thomas Mailund
date: '2018-03-05'
slug: another-approach-to-evaluating-dynprog-expressions
categories:
  - DSL
  - Metaprogramming
tags:
  - dynamic-programming
  - dynprog
---



In the approach to evaluating dynamic-programming expressions, [that I wrote about yesterday](https://mailund.github.io/r-programmer-blog/2018/03/04/evaluating-dynprog-expressions/), I used ranges- and recursion-specifications to build a loop for updating a table and then evaluated that loop inside an environment where local variables would over-scope the quosure environment from the specifications. I constructed the loop-expression like this:


```r
make_loop_expr <- function(tbl_name, update_expr) {
    rlang::expr({
        combs <- do.call(expand.grid, ranges)
        rlang::UQ(tbl_name) <- vector(
            "numeric",
            length = nrow(combs)
        )
        dim(rlang::UQ(tbl_name)) <- Map(length, ranges)
        for (row in seq_along(rlang::UQ(tbl_name))) {
            rlang::UQ(tbl_name)[row] <- with(
                combs[row, , drop = FALSE], {
                    rlang::UQ(update_expr)
                }
            )
        }
        rlang::UQ(tbl_name)
    })
}
```

We can see what this expression looks like if we insert the specifications for computing [Fibonacci numbers](https://en.wikipedia.org/wiki/Fibonacci_number).


```r
fib_ranges <- parse_ranges(rlang::quo({
    n <- 1:10
}))
fib_recursions <- parse_recursion(rlang::quo({
  F[n] <- F[n - 1] + F[n - 2] ? n > 2
  F[n] <- 1                   ? n <= 2
}))
make_loop_expr(get_table_name(fib_recursions$patterns),
                make_update_expr(
                    fib_ranges,
                    fib_recursions$patterns,
                    fib_recursions$conditions,
                    fib_recursions$recursions
                ))
```

```
## {
##     combs <- do.call(expand.grid, ranges)
##     F <- vector("numeric", length = nrow(combs))
##     dim(F) <- Map(length, ranges)
##     for (row in seq_along(F)) {
##         F[row] <- with(combs[row, , drop = FALSE], {
##             if (all(n == n) && n > 2) 
##                 F[n - 1] + F[n - 2]
##             else if (all(n == n) && n <= 2) 
##                 1
##         })
##     }
##     F
## }
```

The loop needs to have access to the dynamic programming table and the index—in the general case indices, when there are more ranges—and on top of that it should be able to see any other variables defined in the scope where the ranges- and recursions-specifications are defined. The `with`-statement inside the loop makes sure that the expression can see the range-indices. If I just evaluated the loop expression in the quosure environment, I would get an error, because the loop needs to know `ranges`, so I solved that by putting the local environment in the evaluation function on top of the quosure-environment and evaluated the loop in this scope:


```r
eval_recursion <- function(ranges, recursions) {
    loop <- make_loop_expr(
                get_table_name(recursions$patterns),
                make_update_expr(
                    ranges,
                    recursions$patterns,
                    recursions$conditions,
                    recursions$recursions
                ))
    eval_env <- rlang::env_clone(
        environment(), # this function environment
        recursions$recursion_env # quosure environment
    )
    eval(loop, envir = eval_env)
}
eval_recursion(fib_ranges, fib_recursions)
```

```
##  [1]  1  1  2  3  5  8 13 21 34 55
```

This works, as we saw yesterday, but it is less than satisfying that we over-scope a bit too much. The function environment puts `loop` and `eval_env` into the evaluation scope—at a position where they will be seen before any variables with the same names in the quosure-scope—and the loop-expression adds `combs` and `row` on top of that.

By design, the solution pollutes the namespace in which I evaluate the recursion.

As an alternative solution, I can loop over the combination of range-indices directly—rather than creating an expression for this—since I know what to loop over from the ranges and do not need to evaluate any expressions for that. I can then evaluate recursions in an environment where I tie together the range-indices from `combs[row,]` with the quosure environment. Well, actually, I need an addition environment to store the dynamic-programming table in, so the recursions have access to that, but I can create this environment with the quosure-environment as parent. Then, if I evaluate expressions in this environment, I have access to both the table and any other variables from the quosure.

There is one more issue, though. I need to use `combs[row,]` to over-scope the environment with the index-variables when evaluating the recursions. This is easy to do with the `eval` function—it takes three arguments, the expression to evaluate, a list containing variable bindings, and an enclosing environment. If I use `combs[row,]` as the second argument and the evaluation environment as the third, I have set up the scope as I want it.

I cannot evaluate an assignment in that setup, though. I won’t get an error, but I won’t be doing any assignment either. If I evaluate an assignment in an `eval`-call with a list as the second argument, I won’t be updating the evaluation environment. That environment is given as the third argument, but `eval` will not try to assign into it, just because it cannot assign into the second argument. Consequently, I have to split up the recursion evaluation and the assignment to the table. I use both `combs[row,]` and the evaluation environment when I compute the value for the recursion, but I use on the evaluation-environment when I assign.

The new solution looks like this:


```r
eval_recursion <- function(ranges, recursions) {
    tbl_name <- get_table_name(recursions$patterns)
    tbl_name_string <- as.character(tbl_name)
    update_expr <- make_update_expr(
        ranges,
        recursions$patterns,
        recursions$conditions,
        recursions$recursions
    )
    eval_env <- rlang::child_env(recursions$recursion_env)
    
    combs <- do.call(expand.grid, ranges)
    tbl <- vector("numeric", length = nrow(combs))
    dim(tbl) <- Map(length, ranges)
    eval_env[[tbl_name_string]] <- tbl
    
    for (row in seq_along(tbl)) {
        val <- eval(
            rlang::expr(rlang::UQ(update_expr)),
            combs[row, , drop = FALSE],
            eval_env
        )
        eval(rlang::expr(
                rlang::UQ(tbl_name)[rlang::UQ(row)] 
                    <- rlang::UQ(val)
            ), eval_env)
    }
    
    eval_env[[tbl_name_string]]
}
```

For Fibonacci numbers, I get this result:


```r
eval_recursion(
    ranges = fib_ranges, 
    recursions = fib_recursions
)
```

```
##  [1]  1  1  2  3  5  8 13 21 34 55
```

For the edit-distance between two strings, I get this result:


```r
x <- c("a", "b", "c")
y <- c("a", "b", "b", "c")
edit_ranges <- parse_ranges(rlang::quo({
    i <- 1:(length(x) + 1)
    j <- 1:(length(y) + 1)
}))
edit_recursions <- parse_recursion(rlang::quo({
  E[1,j] <- j - 1
  E[i,1] <- i - 1
  E[i,j] <- min(
      E[i - 1,j] + 1,
      E[i,j - 1] + 1,
      E[i - 1,j - 1] + (x[i - 1] != y[j - 1])
  )
}))
eval_recursion(
    ranges = edit_ranges, 
    recursions = edit_recursions
)
```

```
##      [,1] [,2] [,3] [,4] [,5]
## [1,]    0    1    2    3    4
## [2,]    1    0    1    2    3
## [3,]    2    1    0    1    2
## [4,]    3    2    1    1    1
```

The results are the same as yesterday—this solution just won’t get confused about local variables that shouldn’t be in scope in the recursions.

I am not entirely sure that the best solution is to evaluate an assignment expression to update the table. I cannot simply update the `tbl` parameter in the loop. R’s copy-on-write semantics will let me update that table but it will not be reflected in the table in the evaluation environment. If I take that approach, I have to reassign the updated table into the evaluation environment explicitly—experiments I did while working on [`tailr`](https://github.com/mailund/tailr) made it clear that such an approach would be slower than using `<-` in the right environment. I don’t know if there are hacks that let me update the table in the other environment in a smarter way. 

If there are, I would love to hear about them.
