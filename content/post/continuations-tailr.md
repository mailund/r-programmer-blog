---
title: "Continuations and `tailr`"
date: 2019-02-25T15:41:36+01:00
tags:
  - functional-programming
  - tail-recursion
  - tailr
categories:
  - Functional-programming
---

Tail recursion is essential in functional programming languages because they can be used to transform function calls into loops. If all recursive calls are the final results of a function call, i.e., you do not do anything to the value you get from a recursive call except returning it, then you can directly update your local variables and loop. You do not need a recursive call at all.

Consider this implementation of a linked list:


```r
cons <- function(car, cdr) list(car = car, cdr = cdr)
```

If we have a list of numbers and want to add them together, then we can write a recursive function.


```r
lst <- cons(1, cons(2, cons(3, NULL)))
list_sum <- function(lst) {
    if (is.null(lst)) 0
    else lst$car + list_sum(lst$cdr)
}
list_sum(lst)
```

```
## [1] 6
```

It solves the problem, but it is not tail-recursive. We add a number to the result of a recursive call.

It is easy to transform it into a tail-recursive function, though. We can add an accumulator to the function. When we call recursively, we update the accumulator, and when we hit the base case, we return it.


```r
list_sum <- function(lst, acc = 0) {
    if (is.null(lst)) acc
    else list_sum(lst$cdr, lst$car + acc)
}
list_sum(lst)
```

```
## [1] 6
```

The first version calls itself recursively all the way to a base case and then it computes the result while going back up the call-stack. Using the accumulator, we do the computation going down the stack, and when we hit the base case, we already know the result. We don’t need to move back up the stack again to return the result, but we have to because we have used function calls.^[The `callCC()` function *will* allow you to terminate early in recursion, but that is not relevant for tail-recursion and this post.]

Because we only compute going down the stack and don’t do anything when we return up the stack, we can translate tail-recursive functions into a loop, and in many cases, we can translate a recursive function into a tail-recursive function by adding an accumulator.

Unfortunately, R does not implement this optimisation. There are good reasons for this, but it means that all recursive calls *are* function calls, even if they are tail-recursive. 

This is not a major problem in R. You can always implement algorithms iteratively. But, often it is easier to solve a problem recursively. If you do implement a solution to a problem using recursive functions, you can easily exceed the call stack.

Not to worry, you can translate a tail-recursive function into a looping-function yourself, or you can use a package that I wrote a little while back: [`tailr`](https://mailund.github.io/tailr/). The package doesn’t handle all tail-recursive R functions. It is not *possible* to translate all tail-recursive functions into loops in R because you can access the call stack if you do a non-standard evaluation. But with `tailr` you can handle most simple recursive functions.^[And if you have a function that it cannot transform, then you are welcome to submit a bug report, or better still, a pull request.]

You translate a function using `tailr::loop_transform()`:


```r
list_sum_tr <- tailr::loop_transform(
    list_sum
)
list_sum_tr(lst)
```

```
## [1] 6
```

The transformed function isn’t pretty, but you are not supposed to look at it, and I have put the original source in the `srcref` attribute, so you generally won’t see the transformation.


```r
list_sum_tr
```

```
## function(lst, acc = 0) {
##     if (is.null(lst)) acc
##     else list_sum(lst$cdr, lst$car + acc)
## }
## <bytecode: 0x7fa61b930e28>
```

For this post, however, you do need to see it. It looks like this:


```r
body(list_sum_tr)
```

```
## .Primitive("{")(.tailr_lst <- lst, .tailr_acc <- acc, callCC(function(escape) {
##     repeat {
##         .Primitive("{")(lst <- .tailr_lst, acc <- .tailr_acc, 
##             {
##                 if (is.null(lst)) 
##                   escape(acc)
##                 else {
##                   .tailr_lst <<- lst$cdr
##                   .tailr_acc <<- lst$car + acc
##                 }
##             }, next)
##     }
## }))
```

You can see the `repeat` loop in there and how I update the local variables instead of calling recursively. (There are prettier ways to updating parameters in an environment, but my benchmarking showed me that this was the fastest of the alternatives I considered).

When I wrote the package, I had hoped that I would get a performance boost from the transformation, but there is a lot of overhead in the looping version, so there isn’t really any gain. For simple functions, a looping version you write yourself will always be faster than the functions that `tailr` creates. They are not slower than recursive functions, so if you *do* use a recursive function, the package is worth considering. Even if you do not get any performance, the transformed functions will not run out of stack space. When you call them, you only put one call frame on the stack.

## Continuations

As long as we only have one recursion, we can add an accumulator and get a tail-recursive function. If you need more than one recursive call, at least one of them cannot be immediately returned. Consider a tree instead of a list:


```r
tree <- function(left, val, right) {
    list(left = left, val = val, right = right)
}
leaf    <- function(val) tree(NULL, val, NULL)
node    <- function(left, right) tree(left, NULL, right)
is_leaf <- function(tree) is.null(tree$left)
val     <- function(tree) tree$val
```

If we want to sum the values in the leaves of a tree, we can use


```r
tree_sum <- function(tree) {
    if (is_leaf(tree)) val(tree)
    else tree_sum(tree$left) + tree_sum(tree$right)
}
tree_sum(leaf(42))
```

```
## [1] 42
```

```r
tree_sum(node(leaf(21),leaf(21)))
```

```
## [1] 42
```

```r
tree_sum(node(node(leaf(10.5),leaf(10.5)),
              node(leaf(10.5),leaf(10.5))))
```

```
## [1] 42
```

The function is not tail-recursive, and you cannot make it tail-recursive by adding an accumulator.

What you can do, is use a *continuation*.^[You can read more about continuations in [*Functional Programming in R*](https://amzn.to/2BSRAEn).]

In the context of recursion, a continuation takes the role of the accumulator. You can think of it as an active accumulator. With an accumulator, we do something to it when we call recursively, but with a continuation, we ask it to continue our computation when we have a value for it.

Consider this version of the list sum:


```r
list_sum <- function(lst, cont = identity) {
    if (is.null(lst)) cont(0)
    else list_sum(lst$cdr, function(val) cont(val + lst$car))
}
list_sum(lst)
```

```
## [1] 6
```

Here, I use a function, called `cont()` and with default argument the `identity()` function (`function(x) x`). It shows up the places where the accumulator did before, but it is a function instead of a number. And the code is a bit more complex. To be honest, it can be a bit hard to grok how continuations work, but I will try to walk you through it.

In the original, not tail-recursive, version of `list_sum()` we went down the recursion until we hit a base case. There, we returned 0. We then added the numbers in the list when we returned from the recursive calls. With the accumulator, we updated the result value when we went down the call stack and were done when we hit the base case. The continuation version does both, but tail-recursive. You can think of the continuation as what you want to do when you return from a recursion. It will do what you did when you got the result of the recursive call in the original function. There, you used

```r
    else lst$car + list_sum(lst$cdr)
```

to add the return value to `lst$car`. The function `function(val) cont(val + lst$car)` in 

```r
    else list_sum(lst$cdr, function(val) cont(val + lst$car))
```

does the same thing. The `val` parameter is the result of the recursive call. We want to return `val + lst$car`, but we then want the evaluation to continue the way it did when we moved up the stack earlier. Therefore, we call our continuation so it will do that remaining computation.

In the base case, the original function returned zero. We need to tell the continuation that its value is zero. So, we replace 

```r
    if (is.null(lst)) 0
```

with

```r
    if (is.null(lst)) cont(0)
```

So, in short, when you go down the recursion, you update the continuation so it does what you would initially do with the value you got from a recursive call. Your continuation will be called with the result of the recursive call, so you just put the original expression in the body of the continuation. To return a value, you need to call the continuation. If you don't the final result of the computation is the last value you return. The continuation is what ties together your recursion and what you should return.

It is because we put the computations we would do when returning from recursions into the continuation that the function is tail-recursive.

We can rewrite the `tree_sum()` function so it uses continuations:



```r
tree_sum <- function(tree, cont = identity) {
    if (is_leaf(tree)) {
        cont(val(tree))
    } else {
        tree_sum(
            tree$left,
            function(left_val) {
                tree_sum(tree$right, function(right_val) {
                    cont(left_val + right_val)
                })
            }
        )
    }
}
```

We can then check that it computes the same values as before:


```r
tree_sum(leaf(42))
```

```
## [1] 42
```

```r
tree_sum(node(leaf(21),leaf(21)))
```

```
## [1] 42
```

```r
tree_sum(node(node(leaf(10.5),leaf(10.5)),
              node(leaf(10.5),leaf(10.5))))
```

```
## [1] 42
```

This function is a little harder to unpack, but you will see that we first have a recursive call on the left tree:

```r
        tree_sum(
            tree$left,
            function(left_val)...
        )
```

The continuation we pass along with the call will get the result of the recursion so it will get the value we get when traversing the left tree. 

This continuation needs to make the second recursive call, on the right tree:

```r
            function(left_val) {
                tree_sum(
                    tree$right,
                    function(right_val) ...
                )
            }
```

The continuation we pass along here will get the result from the traversal of the right tree.

What we want to return from the function is the left value plus the right value. We return the result by calling the first continuation:

```r
        cont(left_val + right_val)
```

Now, I wanted to check if `tailr` would play well with continuations (and suspected it would not). For the rest of this post, you need the latest development version of `tailr` if you want to try the code. I should make a new release soon, but before that, I need to make a new version of `pmatch`, and I have a bug there I haven’t had time to look at yet.

Straight ahead we can try to transform the function.


```r
tree_sum_tr <- tailr::loop_transform(tree_sum)
tree_sum_tr(leaf(42))
```

```
## [1] 42
```

Looking good! It works on one example, so it is probably fine.


```r
tree_sum_tr(node(leaf(21),leaf(21)))
```

```
## Error: evaluation nested too deeply: infinite recursion / options(expressions=)?
```

Well, that's not good.

To see what is wrong we can look at the transformed function's code:


```r
body(tree_sum_tr)
```

```
## .Primitive("{")(.tailr_tree <- tree, .tailr_cont <- cont, callCC(function(escape) {
##     repeat {
##         .Primitive("{")(tree <- .tailr_tree, cont <- .tailr_cont, 
##             {
##                 if (is_leaf(tree)) {
##                   escape(cont(val(tree)))
##                 }
##                 else {
##                   {
##                     .tailr_tree <<- tree$left
##                     .tailr_cont <<- function(left_val) {
##                       tree_sum(tree$right, function(right_val) {
##                         cont(left_val + right_val)
##                       })
##                     }
##                   }
##                 }
##             }, next)
##     }
## }))
```

It might not be apparent right away, but if you stare at it long enough you will notice that we override the `cont` variable in each loop, so when we call it from one of the continuations we create, we will call the wrong function. This is one of those dangers you run into when you allow assignments to variables...

We need to capture the closure of a function when we create it as a continuation. This function does exactly that:


```r
capture <- function(.func) {
    captured_env <- rlang::env_clone(rlang::caller_env())
    environment(.func) <- captured_env
    .func
}
```

It makes a copy of the caller's environment and makes that the environment for the function. This isn't a cheap operation, so expect some runtime penalty, but it makes sure that the variable bindings we have at the time we create a continuation will not be overridden in the loop.

With the `capture()` function, it all works.


```r
tree_sum <- function(tree, cont = identity) {
    if (is_leaf(tree)) {
        cont(val(tree))
    } else {
        tree_sum(
            tree$left,
            capture(function(left_val) {
                tree_sum(tree$right, function(right_val) {
                    cont(left_val + right_val)
                })
            })
        )
    }
}
tree_sum_tr <- tailr::loop_transform(tree_sum)

tree_sum_tr(leaf(42))
```

```
## [1] 42
```

```r
tree_sum_tr(node(leaf(21),leaf(21)))
```

```
## [1] 42
```

```r
tree_sum_tr(node(node(leaf(10.5),leaf(10.5)),
                 node(leaf(10.5),leaf(10.5))))
```

```
## [1] 42
```

If you do not use the most recent version of `tailr`, you cannot transform the function. The earlier transformation code would not accept a recursive call nested in another function. Not that this would ever be a problem, but I didn't handle the case. I do now.

Since we do not need to worry about the closure once we have captured it, we can also name our continuations and make the code a bit more readable.


```r
tree_sum <- function(tree, cont = identity) {
    if (is_leaf(tree)) {
        cont(val(tree))
    } else {
        left_cont <- capture(
            function(left_val) {
                right_cont <- function(right_val) {
                    cont(left_val + right_val)
                }
                tree_sum(tree$right, right_cont)
            }
        )
        tree_sum(tree$left, left_cont)
    }
}
```

There you go: rewriting tail-recursive functions with continuations.

In [*Functional Programming in R*](https://amzn.to/2BSRAEn) I describe a different way to get a tail-recursive implementation of continuation-passing-style tail-recursive functions. It does not involve rewriting functions, but you need to capture them in thunks, similar to how we capture their closure here. If you want to know how that works, you can read [this post](https://mailund.github.io/r-programmer-blog/2018/10/10/thunks-and-trampolines/). There, I also try to explain closures, so it if isn't entirely clear how they work yet, maybe reading a different explanation will help.

**Update 27/2/2019:** Actually, this doesn’t work as advertised. It just moves the call stack length from the recursions to the continuations. When we return from the recursion we call a continuation that calls another continuation that calls another continuation and so on. This can be fixed, but I don’t think it can be fixed to be more efficient than the [trampoline approach](https://mailund.github.io/r-programmer-blog/2018/10/10/thunks-and-trampolines/). If I can think up a more efficient way, then I will let you know.

Now I am just thinking about how to automatically translate a recursive function into the thunk/trampoline pattern.

