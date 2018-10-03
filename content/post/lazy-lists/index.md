---
title: "Lazy lists"
date: '2018-10-03T09:13:01+02:00'
tags:
  - functional-programming
  - pmatch
categories:
  - Data-structures
---

I wanted to write about lazy lists and lazy queues today, but I spent most of the day struggling with getting lazy evaluation to work. Finally, I convinced myself that something was broken in R, and I was justified in thinking that; upgrading to the most recent version resolved the issue.

Since I spent too long with this problem, I won't have time to implement lazy queues today, but I can tell you how lazy lists are implemented.

## Lazy lists

I described how linked lists can be implemented using my `pmatch` package [here](https://mailund.github.io/r-programmer-blog/2018/10/01/lists-and-functional-queues/). I won't repeat it here; only repeat the code:


```r
library(pmatch)

linked_list := NIL | CONS(car, cdr)
toString.linked_list <- function(llist)
  cases(llist, NIL -> "[]",
        CONS(car, cdr) -> paste(car, "::", toString(cdr)))
print.linked_list <- function(llist)
  cat(toString(llist), "\n")
```

With these lists, we can do everything that we usually want to do with linked lists, but these are "eager" lists, and sometimes we want lazy lists. By this, I mean that when we write an expression that manipulates a lists, we don't want it evaluated until we need it. This can be achieved using thunks without any effort. However, we also want to remember the results of evaluating expressions, so we do not have to re-evaluate them. Thunks, by themselves, do not do this. R promises do.

I am going to implement lazy lists as linked lists, except that the `cdr` will always be a thunk. And to compare lazy versus eager evaluation I will use two different thunks:


```r
make_eager_thunk <- function(expr) {
  force(expr)
  THUNK(function() expr)
}
make_lazy_thunk <- function(expr) {
  THUNK(function() expr)
}
```

As you can see, the only difference is that the first force its promise while the second does not.

We can write code that assumes that a lazy list is always a thunk, and all the code below would work. We can't pattern match against empty and non-empty lazy lists this way, though, and when I implement lazy queues, I want to be able to do that.

So, I define a type for lazy lists; it is either an empty lazy list or a thunk.


```r
lazy_list := LLNIL | THUNK(lst)
toString.lazy_list <- function(x)
  cases(x,
        LLNIL -> "<>",
        THUNK(y) ->
          cases(y(),
            NIL -> "<>",
            CONS(car, cdr) -> paste(car, ":: <...>")))
print.lazy_list <- function(x)
  cat(toString(x), "\n")
```

We cannot use `NIL` for the empty lazy list since that constructor is already used for linked lists.

The pattern matching that first checks if a lazy list is empty, evaluate it if not and then checks if the linked list is empty before dealing with non-empty lists is very tedious to write, so I will use this macro.

It uses some tidy-evaluate so you might find it interesting if you like non-standard evaluation. If not, you can skip the function.


```r
lazy_macro <- function(empty_pattern, nonempty_pattern, ...) {
  
  empty_pattern    <- substitute(empty_pattern)
  nonempty_pattern <- substitute(nonempty_pattern)
  extra_args       <- rlang::enexprs(...)
  
  cases_pattern <- rlang::expr(
    cases(.list,
          LLNIL -> !!empty_pattern,
          THUNK(.list_thunk) ->
            cases(.list_thunk(),
                  NIL -> !!empty_pattern,
                  CONS(car, cdr) -> !!nonempty_pattern))
  )
  function_expr <- rlang::expr(
    rlang::new_function(
      alist(.list =, !!!extra_args), 
      cases_pattern, 
      env = rlang::caller_env())  
  )
  
  rlang::eval_bare(function_expr)
}
```

The macro takes two+ arguments. The first says what to do when the list is empty, the second what to do when it is not, and any additional arguments are used as arguments for the function it defines.

If you add additional arguments, you cannot just provide their names, as you would for normal functions. You have to follow the names with `=`. You will see this below. That is just how it must be done to insert them in the `alist` we need to define the new function.

We can use `lazy_macro` to redefine `toString`, and I think you will agree that this definition is easier to write.


```r
toString.lazy_list <- lazy_macro("<>", paste(car, ":: <...>"))
```


For constructing lists, I use these two convinience functions:


```r
eager_cons <- function(car, cdr) make_eager_thunk(CONS(car, cdr))
lazy_cons  <- function(car, cdr) make_lazy_thunk(CONS(car, cdr))
```

These are also useful for the example code below. I use them to avoid pattern-matching everywhere I access lists.


```r
car <- lazy_macro(stop("Empty list"), car)
cdr <- lazy_macro(stop("Empty list"), cdr)
```

We can construct an eager list using `purrr::reduce`:


```r
x <- purrr::reduce(1:5, ~ eager_cons(.y, .x), .init = LLNIL)
x
```

```
## 5 :: <...>
```

```r
car(x)
```

```
## [1] 5
```

```r
cdr(x)
```

```
## 4 :: <...>
```


```r
y <- purrr::reduce(1:5, ~ lazy_cons(.y, .x), .init = LLNIL)
y
```

```
## 5 :: <...>
```

```r
car(y)
```

```
## [1] 5
```

```r
cdr(y)
```

```
## 5 :: <...>
```

This doesn't show the difference between eager and lazy evaluation, because as soon as we look into a list, we get the evaluated results.

We can reveal the evaluation by wrapping values in a "noisy" function:


```r
make_noise <- function(val) {
  cat("I see", val, "\n")
  val
}
```

This reveals that with the eager construction, the function is created right away.


```r
x <- purrr::reduce_right(1:5, ~ eager_cons(make_noise(.y), .x), .init = LLNIL)
```

```
## I see 5 
## I see 4 
## I see 3 
## I see 2 
## I see 1
```

When we access it, we do not re-evaluate. It is already created.


```r
car(x)
```

```
## [1] 1
```

```r
car(cdr(x))
```

```
## [1] 2
```

With lazy constructions, we do not evaluate the list when we create it


```r
y <- purrr::reduce_right(1:5, ~ lazy_cons(make_noise(.y), .x), .init = LLNIL)
```

We construct the elements when we access them.


```r
car(y)
```

```
## I see 1
```

```
## [1] 1
```

```r
car(cdr(y))
```

```
## [1] 1
```

Wait, what? Why do we get 1 twice here?

This is a consequence of lazy evaluation of promises that we did *not* want here. When we use `purrr:reduce_right`, we have an environment with variables that are updated while `purrr::reduce_right` moves through `1:5`. When we evaluate the lazy thunk, that is when we evaluate the expression `lazy_cons(make_noise(.y), .x)`. This is too late; we only get the last value that the variables in the function referred to. 

It is slightly worse than it looks like here. The `car` of the list is the last value, 5, but what is worse is that `cdr` of the list is the list itself. If we tried to scan through the lazy list, we would get an infinite loop

This function translates a lazy list into a linked list. It shows us that we can scan through the eager list


```r
lazy_to_llist <- lazy_macro(NIL, CONS(car, lazy_to_llist(cdr)))
lazy_to_llist(x)
```

```
## 1 :: 2 :: 3 :: 4 :: 5 :: []
```

But don't try this. You will hit the limit of the recursion stack.

```r
lazy_to_llist(y)
```

I cannot show the result here. You will not get a usual R error that `knitr` can show. Your R session won't crash or anything, so you can try it if you want to. I simply can't show the result here. It will look something like this, though

```
Error: C stack usage  7969360 is too close to the limit
Execution halted
```

We can't use `purrr` to construct lazy lists, but this will work.


```r
list_to_lazy_list <- function(lst, i = 1) {
  if (i > length(lst)) LLNIL
  else lazy_cons(make_noise(lst[i]), list_to_lazy_list(lst, i + 1))
}
```

Again, we can check that the elements we give the list are not evaluated when we create it:


```r
y <- list_to_lazy_list(1:5)
```

They are when we scan through the list:


```r
lazy_to_llist(y)
```

```
## I see 1 
## I see 2 
## I see 3 
## I see 4 
## I see 5
```

```
## 1 :: 2 :: 3 :: 4 :: 5 :: []
```

If you want to use this function in the future, you will want to remove the `make_noise` call, but I use it here to reveal when lists are evaluated in the examples below as well.

To make the examples below easier to read, I will also make a function for creating eager lists:


```r
list_to_eager_list <- function(lst)
  purrr::reduce_right(lst, ~ eager_cons(make_noise(.y), .x), .init = LLNIL)
```

Eager lists are still evaluated when we construct them:


```r
x <- list_to_eager_list(10:15)
```

```
## I see 15 
## I see 14 
## I see 13 
## I see 12 
## I see 11 
## I see 10
```

and therefore not when we scan through them:


```r
lazy_to_llist(x)
```

```
## 10 :: 11 :: 12 :: 13 :: 14 :: 15 :: []
```

Finally, we get to the good part. Lazy concatenation.

With eager lists, concatenating two lists will take time proportional to the length of the first list. With lazy evaluation, it is a constant time operation. Instead of concatenating immediately, we construct a thunk that gives us the head of a list and a thunk for concatenating the rest.

An eager and a lazy version would look like this


```r
eager_concat <- lazy_macro(second, eager_cons(car, eager_concat(cdr, second)), second =)
lazy_concat  <- lazy_macro(second, lazy_cons(car, lazy_concat(cdr, second)), second =)
```

Now, create two new lists to experiment with


```r
x <- list_to_eager_list(10:15)
```

```
## I see 15 
## I see 14 
## I see 13 
## I see 12 
## I see 11 
## I see 10
```

```r
y <- list_to_lazy_list(1:5)
```

If we concatenate `y` to `x`, we do not evaluate any elements. The eager list is already constructed, and the concatenation does not scan the lazy list:


```r
eager_concat(x, y)
```

```
## 10 :: <...>
```

In the other direction, we will evaluate the lazy list.


```r
eager_concat(y, x)
```

```
## I see 1 
## I see 2 
## I see 3 
## I see 4 
## I see 5
```

```
## 1 :: <...>
```

We evaluate it because this concatenation is eager.

Now, let us try lazy concatenation. We need new lists for this; the old ones are already evaluated.


```r
x <- list_to_eager_list(10:15)
```

```
## I see 15 
## I see 14 
## I see 13 
## I see 12 
## I see 11 
## I see 10
```

```r
y <- list_to_lazy_list(1:5)
```

With lazy evaluation, neither order of concatenation will evaluate the entire lazy list:


```r
xy <- lazy_concat(x, y)
yx <- lazy_concat(y, x)
```

```
## I see 1
```

We do evaluate the first element because even the lazy concatenation gets the `car` of its input.

The eager one is already evaluated, as before.

If we scan through the concatenated lists, we will evaluate the rest of the lazy one:


```r
lazy_to_llist(xy)
```

```
## I see 2 
## I see 3 
## I see 4 
## I see 5
```

```
## 10 :: 11 :: 12 :: 13 :: 14 :: 15 :: 1 :: 2 :: 3 :: 4 :: 5 :: []
```

We only evaluate the list once. If we scan through it again, even if it is part of another concatenated list, we have already evaluated it.


```r
lazy_to_llist(yx)
```

```
## 1 :: 2 :: 3 :: 4 :: 5 :: 10 :: 11 :: 12 :: 13 :: 14 :: 15 :: []
```

It is the combination of lazy evaluation and remebering results that will allow us to implement persisten functional queues with amortised constant time operations. But I am out of time today, so that will have to be in another post.

<hr/>
<small>If you liked what you read, and want more like it, consider supporting me at [Patreon](https://www.patreon.com/mailund).</small>
<hr/>
