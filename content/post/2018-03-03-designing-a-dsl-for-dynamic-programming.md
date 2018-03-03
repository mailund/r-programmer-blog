---
title: Designing a DSL for dynamic programming
author: Thomas Mailund
date: '2018-03-03'
slug: designing-a-dsl-for-dynamic-programming
categories:
  - DSL
  - Metaprogramming
tags: ["dynamic-programming", "dynprog"]
---

I'm working on an example for one of the chapters of [Domain Specific Languages in R](http://amzn.to/2FO5MiQ) that will appear in the printed version but weren't included in the earlier e-book. The plan is to have one to three extra example chapters, depending on how much I can do before my deadline on April 1st. The first of these is a domain-specific language for specifying dynamic programming algorithms. The code will also be available as an R package I have named `dynprog`. You can get the current version on [GitHub](https://github.com/mailund/dynprog). You can, of course, install it from GitHub using `devtools`, 


```r
devtools::install_github("mailund/dynprog")
```

but there is no functionality yet, so there is little point to doing that.

Anyway, my plan is to have functionality that fills out a dynamic programming table based on a recursion specification.

The syntax I've come up with looks like this for specifying a table of factorial values:


```r
fact <- fact %with% {
  fact[n] <- n * fact[n - 1] ? n >= 1
  fact[n] <- 1               ? n < 1
} %where% {n <- 1:4}
```

I use two top-level infix operators, `%with%` and `%where%` to specify a recursion. With `%with%` (no pun) I specify the table to fill out and the recursion and `%where%` then combines the recursion with a ranges the algorithm should iterate over.

Another example, for computing the edit-distance between two strings, could look like this:


```r
x <- "abccd"
y <- "abd"
edit <- edit %with% {
  edit[1,j] <- j
  edit[i,1] <- i
  edit[i,j] <- min(edit[i - 1,j] + 1,
                   edit[i,j - 1] + 1,
                   edit[i - 1,j - 1] + x[i] == y[j]) ? i > 1 && j > 1
} %where% {i <- seq_along(x) ; j <- seq_along(y)}
```

I'm not entirely sure I need the `%with%` operator. It is just a piece of syntax to get the recursion started, but I don't use the first argument, the table name, to anything yet. I can get it from the recursions if I wanted to, but I am not sure that I need it at all. So maybe I will end up with just a `%where%` operator and the recursions could look like this:


```r
fact <- {
  fact[n] <- n * fact[n - 1] ? n >= 1
  fact[n] <- 1               ? n < 1
} %where% {n <- 1:4}

x <- "abccd"
y <- "abd"
edit <- {
  edit[1,j] <- j
  edit[i,1] <- i
  edit[i,j] <- min(edit[i - 1,j] + 1,
                   edit[i,j - 1] + 1,
                   edit[i - 1,j - 1] + x[i] == y[j]) ? i > 1 && j > 1
} %where% {i <- seq_along(x) ; j <- seq_along(y)}
```

I can't decide whether I want a keyword at the beginning of the recursion to make clear that we now have an expression in the DSL or go for the simpler solution with only one keyword/infix operator.

Whether I keep `%with%` or not, the specification consists of a recursion and a set of ranges to evaluate the the recursion over. Both of these are a sequence of assignments. Of the two, the ranges specification is the simplest. Here, I just consider the sequence of assignments a list of iterator variables and the values they should iterate over in when I evaluate the recursion.

There is more meat to the recursion specification. When I evaluate a full expression I want to iterate over the ranges and assign into a table for each combination of the ranges. The value to assign will be picked from the list of recursions. Here, I plan to make the semantics that I use the first expression where the conditions for the recursion are met, and I have two ways of specifying conditions. I have the patterns for the table cell to the left of the assignment and, optionally, I have conditions following `?` in the expressions.

You are probably familiar with `?` as a way of getting documentation for functions in R, but it is also considered an infix operator by the R parser, so you can use it in meta-programming like here. It has the highest precedence, so I can always check if a recursion has such a condition by checking if it is a call to `?`. I could also have defined a new infix operator, like `%if%` or `%when%`, but then I would have to worry about operator precedence or force users to add parentheses around the conditions. With `?`, I avoid that issue completely.

I have written the parser for the DSL now. I parse ranges into a list of the values provided in that part of the expression and I translate the recursion specification into three lists: `patterns` for the left-hand-side of the recursion assignments, `conditions` for the right-hand-side of `?` expressions, and finally `recursions` for the actual expression. To keep the scope in which the recursions should be evaluated, over-scoped by ranges, of course, I store that with the lists as well. An alternative would be to represent all the `recursions` expressions as quosures, but they will all have the same scope if they are from the same DSL expression, so I don't see the point in that.

The parsed information for the `factorial` expression, in the version without `%with%`, looks like this:


```r
library(dynprog)
fact <- {
  fact[n] <- n * fact[n - 1] ? n >= 1
  fact[n] <- 1               ? n < 1
} %where% {n <- 1:4}
fact
```

```
## $recursions
## $recursions$recursion_env
## <environment: R_GlobalEnv>
## 
## $recursions$patterns
## $recursions$patterns[[1]]
## fact[n]
## 
## $recursions$patterns[[2]]
## fact[n]
## 
## 
## $recursions$conditions
## $recursions$conditions[[1]]
## n >= 1
## 
## $recursions$conditions[[2]]
## n < 1
## 
## 
## $recursions$recursions
## $recursions$recursions[[1]]
## n * fact[n - 1]
## 
## $recursions$recursions[[2]]
## [1] 1
## 
## 
## 
## $ranges
## $ranges$n
## [1] 1 2 3 4
```

For edit distance, the parsed information is this:


```r
x <- "abccd"
y <- "abd"
edit <- {
  edit[1,j] <- j
  edit[i,1] <- i
  edit[i,j] <- min(edit[i - 1,j] + 1,
                   edit[i,j - 1] + 1,
                   edit[i - 1,j - 1] + x[i] == y[j]) ? i > 1 && j > 1
} %where% {i <- seq_along(x) ; j <- seq_along(y)}
edit
```

```
## $recursions
## $recursions$recursion_env
## <environment: R_GlobalEnv>
## 
## $recursions$patterns
## $recursions$patterns[[1]]
## edit[1, j]
## 
## $recursions$patterns[[2]]
## edit[i, 1]
## 
## $recursions$patterns[[3]]
## edit[i, j]
## 
## 
## $recursions$conditions
## $recursions$conditions[[1]]
## [1] TRUE
## 
## $recursions$conditions[[2]]
## [1] TRUE
## 
## $recursions$conditions[[3]]
## i > 1 && j > 1
## 
## 
## $recursions$recursions
## $recursions$recursions[[1]]
## j
## 
## $recursions$recursions[[2]]
## i
## 
## $recursions$recursions[[3]]
## min(edit[i - 1, j] + 1, edit[i, j - 1] + 1, edit[i - 1, j - 1] + 
##     x[i] == y[j])
## 
## 
## 
## $ranges
## $ranges$i
## [1] 1
## 
## $ranges$j
## [1] 1
```

The next step is now to build the functionality to pick the right expression to evaluate when iterating over the ranges. Here, I need to do some pattern-matching similar to [`pmatch`](http://github.com/mailund/pmatch) on the `patterns` list and then combine that with evaluating the `conditions` for the different values of ranges indices. I can go through the recursions from top to bottom, and evaluate the first expression where both the pattern and condition match, and then put the result into the dynamic programming table.

Sounds simple enough.

My guess is it will take about a day to implement. I don't have that today or tomorrow, but maybe I can manage Monday.
