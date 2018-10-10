---
title: "Thunks and Trampolines"
date: 2018-10-10T15:38:25+02:00
tags:
  - functional-programming
  - tail-recursion
categories:
  - Functional-programming
---


Have you ever written a recursive function that you couldn't use because you ran out of stack space when you applied it to large data sizes? Then thunks and trampolines might be for you.

I wrote about this in [*Functional Programming in R*](https://amzn.to/2IQEtWM) but looked at it again today. I am giving a 10-minute seminar for our weekly breakfast meeting here at BiRC in a few weeks, and I thought I could talk about this there.

Now, I realise that this would be insanely optimistic. It is not that the tricks that I am going to give you below are difficult. Once you understand them, they are easy to apply. But you do need to wrap your head about two clever ideas, and that takes a little time.

## Recursion and stack place

I have written before about tail-recursion and how I have attempted to [implement the tail-recursion optimisation in R](https://mailund.github.io/tailr/). I thought I had actually managed to do this in a way that I got some performance improvements, but that was errors in the experiment. Embarrassing, but contrary to what you might believe, I’m only human.

I’m not sure how difficult it would be to get a performance boost if I were just a little smarter, but the performance of tail-recursive functions is not the purpose of this post. I want, instead, to show you how you can limit your stack-space usage tremendously if you always write tail-recursive functions and use one more trick.

While it might not be obvious, you can always translate a recursive function into a tail-recursive function in R. I will tell you how in the next section. In the section after that, I will tell you how you write recursive functions without doing any recursive function calls.

But, first a quick reminder about recursive and tail-recursive functions. If you write a recursive function, for example, to get the length of a linked list, you can do it recursively.


```r
library(pmatch)
List := Nil | List(head, tail : List)

list_length <- function(lst) {
    cases(lst,
          Nil -> 0,
          List(head, tail) -> 1 + list_length(tail))
}
```

This is not the most efficient way to do this in R—you would use a loop, which despite its reputation is a lot faster than function calls. You can easily use a loop because running through a list is a particularly simple thing to do. There are problems, such as tree traversal, that are considerably easier to handle recursively than iteratively.



Anyway, if you have a recursive function and you need to traverse a large data structure, you could run into this:

```
Error: evaluation nested too deeply: infinite recursion / options(expressions=)?
Error during wrapup: evaluation nested too deeply: infinite recursion / options(expressions=)?
```

I don’t know what the stack limit is, but I know that I usually hit it with a list around a thousand links deep.

The call stack is a limited resource. You can easily construct link lists that are far longer than you can recurse through. 

Again, you wouldn’t use recursion in this case, but the same problem happens if you need to traverse a tree. A balanced tree is unlikely to cause problems. The base two logarithm of a thousand is ten. You need huge trees to get into any trouble if the trees are balanced.

You are not that lucky if you have unbalanced trees—and there are many applications where that could be the case.

## Tail recursion

In many programming languages, changing your recursive function into a tail-recursive function will solve the problem. If the language implements the tail-recursion optimisation, then those functions are translated into loops. You won’t use the stack for the recursive calls at all.

R does not implement this optimisation. If it did, then non-standard evaluation would be harder to do, either because the semantics of R would change or because you would need some serious control-flow analysis to handle it. But using tail-recursive functions is the first step towards a general solution to this stack-space problem.

I will stick with the list example for a little bit, even though it is only a toy example. It is precisely because it is a toy example. The concepts are easier to explain with a simple problem than a more complicated one, after all.

A tail-recursive function is one in which where you either return a value or you return the result of a recursive call. You never take the value returned from the recursive call, you do not do anything with that, you just call a recursion as the final statement in the function.

For many recursive functions, you can use an accumulator to get tail-recursion. Instead of calculating a value when you return from a recursive call, you do the calculation while you move down the recursion.

The list length function calls itself recursively to get the length of the tail of the input list and then add one. But you could just as easily add one to the length of the list that came before the cell. It would look like this:


```r
list_length <- function(lst, acc = 0) {
    cases(lst,
          Nil -> acc,
          List(head, tail) -> list_length(tail, acc + 1))
}
```

We update the accumulator `acc` when we make the recursive call instead of evaluating an expression that involves a recursive call.

I have already hinted that tree traversal is more likely to involved recursion, so let us consider a simple problem for trees: computing the size of a tree. By this, I mean counting the number of nodes.

A straightforward implementation is this:


```r
Tree := Leaf(val) | Tree(left : Tree, right : Tree)

tree_size <- function(tree) {
    cases(tree,
          Leaf(.) -> 1,
          Tree(left, right) -> tree_size(left) + tree_size(right) + 1)
}
```



You cannot use an accumulator to get a tail-recursive function here. You need two recursive calls, and no matter how much you stare at it, you cannot make both of them the last expression in the function.

Another example: consider a search tree. Writing a tail-recursive function to search in a search tree is trivial, but it is hard to write one for inserting a new element into one.

In the definition of search trees below I use empty leaves. It makes it a lot easier to insert elements (see, e.g. [*Functional Data Structures in R*](https://amzn.to/2QIDJWk)).

A straightforward way to insert elements into a search tree is to check if you need to go down the left or right path when you search for a key, and either stop when you find that the key is already in the tree or insert it if you get down to a leaf.


```r
SearchTree := STEmpty | ST(left : SearchTree, key, right : SearchTree)

insert <- function(tree, key) {
    cases(tree,
          STEmpty -> ST(STEmpty, key, STEmpty),
          ST(left, k, right) ->
              if (k < key) ST(left, k, insert(right, key))
              else if (k > key) ST(insert(left, key), k, right)
              else ST(left, key, right)
    )
}
```



Data is immutable in R unless you use R6 classes or environments at least. So you cannot modify a tree. Instead, when you insert a new element, you are building a new tree that contains all the elements in the old tree plus the new element. The tree you are building is constructed when you return from recursive calls.

Inserting elements in a search tree is another example of a function that is hard to translate into a tail-recursive function.

## Continuations

Continuations ride to the rescue.

Continuations give you a different way of thinking about recursion. Instead of computing values when returning from recursive calls, or when going down recursions as you can with an accumulator, you create a function that knows what to do with the value of a recursive call, and then you give it to the recursive call. The recursive call is responsible for calling the function you give it when it knows its answer. When it does, you can continue the computation.^[The `callCC` function in R is based on the idea of continuations. The `CC` in the name stands for *current continuation*. The current continuation is whatever you are in the middle of doing. You tell `callCC` to do some computations by giving it a function for doing this computation. The function you give `callCC` should take one argument, the continuation. When it is done, it should call the continuation with the result. When it does that, the control flow goes back to where you called `callCC`. You can use it to directly return to the `callCC` point from an arbitrarily deep call stack. The continuations I write in this post are not that clever, but the concept is the same.]

We call this way of computing *continuation passing style*, and a continuation passing style function for computing the length of a list would look like this:


```r
list_length <- function(lst, cont = identity) {
    add_one <- function(len) cont(len + 1)
    cases(lst,
          Nil -> cont(0),
          List(head, tail) -> list_length(tail, add_one))
}
```

The list takes a continuation as an argument—exactly like the earlier tail-recursive function got an accumulator. That is where the caller wants to continue with its computation, so you have to call it when you are done.

Here, we are done with the recursion when we hit the end of the list, so that is where we call the continuation. We call it with zero because that is the length of the empty list. If you are deep in a recursion, then control goes back to continuations created earlier, and the number can be changed, as indeed it is, but if this is the first call to `list_length`, then the continuation is the identity function, so we get the value zero, which is correct for the empty list.

In the recursion case, we need to add one to the result of the recursive call. So we create a continuation that adds one to the result of the recursion. We do not add one to a recursive call directly; we just expect that the function we call will call the continuation when it has computed a value, and that is the way we get this value that we can modify.

I know that this way of thinking can be painful at first, but go through the example and convince yourself that it works. It is a beautifully clever trick, so even if you never use it in your code, it is worth knowing about it just for its elegance.

The problem we have with creating tail-recursive function is handling cases with more than one recursive call. The solution is to have more continuations.

If you have a binary operation that you want to use on two recursive calls, like this

```
    rec_func(lhs) op rec_func(rhu)
```

then you construct a continuation that will be called when the recursive function has figured out what the result of `rec_function(lhs)` will be. That function has to continue the computation, so it needs to make a recursive call on the right-hand side of the operation. It already knows the result of the recursive call on the left so it constructs a continuation that, when it knows the result of the right-hand side as well, can compute the original value.

```
    left_cont <- function(left_res) {
        right_cont <- function(right_res)
            make_thunk(cont, op(left_res, right_res))
        make_thunk(rec_func, rhs, right_cont)
    }
    make_thunk(rec_func, lhs, left_cont)
```

The function for computing the size of a tree is slightly more complicated than a binary operator—it needs to add one to the result of the sum of sizes—but that is solved in the continuation. The function looks like this, and is tail-recursive:


```r
tree_size <- function(tree, cont = identity) {
    cases(tree,
          Leaf(.) -> cont(1),
          Tree(left, right) -> {
              go_right <- function(left_res) {
                  add_results <- function(right_res) cont(left_res + right_res + 1)
                  tree_size(right, add_results)
              }
              tree_size(left, go_right)
          })
}
```

When you insert elements into a search tree, you only make one recursive call. You will only need one result from a recursive call, so you do not need to create continuations inside other continuations. We still need continuations to construct a tree when we know the result of a recursive call, though.

We can use two continuations. One handle the case where we recurse to the right, and where the result should have the updated tree as its right subtree. The other handles the left case and should create a tree where the left tree is updated. You then use the continuation that matches the recursive case that you use:


```r
insert <- function(tree, key, cont = identity) {
    cases(tree,
          STEmpty -> cont(ST(STEmpty, key, STEmpty)),
          ST(left, k, right) -> {
              right_cont <- function(res) ST(left, k, res)
              left_cont <- function(res) ST(res, k, right)

              if (k < key) insert(right, key, right_cont)
              else if (k > key) insert(left, key, left_cont)
              else cont(ST(left, key, right))
          }
    )
}
```

Continuation passing style does not solve the issue with the call stack. It makes it worse. You go deeper into the call stack when you go down the recursion, and then you go even deeper when you have to evaluate all the continuations.

We have used a conceptually tricky idea to make our problem twice as bad. It is madness!

Except, once you have tail-recursive functions, you can get rid of the recursion altogether. Instead of making recursive calls, you wrap up the call and put it in a thunk—a function that takes no arguments but does the work that the recursive function would otherwise do.

You cannot make recursive calls from the thunk either. That would defeat the purpose of the thunk. Instead of a recursive call, you create a thunk. The transformation from recursion to thunks is also recursive. Not surprisingly, once you think about it.

## Thunks and trampolines



You can create a thunk from a function and the arguments you want to call it with using this function:


```r
make_thunk <- function(f, ...) {
    force(f)
    args <- list(...)
    function() f(...)
}
```

You break lazy evaluation of the `…` arguments here, but it isn’t frightfully important (and I don’t remember how to avoid this at the moment if it is even possible).^[You can think of thunks as lazy evaluation, and I have seen them described as such. They are lazy in the sense that you postpone a computation. They are not doing what you would hope lazy evaluation would do, though, and [what you can get from promises](https://mailund.github.io/r-programmer-blog/2018/10/02/promises-their-environments-and-how-we-evaluate-them/). They do not remember the result of their evaluation—at least not unless you do some `<<-` assignment to put a result in its closure. Anyway, just know that there is a difference.]

Now, if you create a thunk instead of making a recursive call, you need to evaluate the thunk. If that thunk returns another thunk—it will do that if it has to handle a recursive case—then you also need to evaluate that thunk.

You have to keep evaluating thunks as long as that is what you get back from evaluating them. This is called bouncing, and you can implement with a while loop and using the `is.function` function.


```r
bounce <- function(f) {
    while (is.function(f))
        f <- f()
    f
}
```

This, of course, means that you cannot return a function from the recursion. There are ways around this—for example, you can give thunks a class and use generic functions—but it is a minor issue. We do not usually return functions in recursive computations.

I do not know why this is called bouncing. One of the explanations for why thunks are called thunks is that it is the sound made by data hitting the stack, and if you keep getting thunks from thunks I suppose you could think of that as a thunk bouncing up and down. I don’t know. It is called bouncing, and that is just how it is.

Because we now have bouncing thunks instead of recursive calls, we need always to bounce our recursive functions. If you want a lot of bouncing, you need a trampoline. You can translate a bouncing function into one you can call normally and get a value back, but putting it on a trampoline like this:


```r
trampoline <- function(f) {
    force(f)
    function(...) bounce(f(...))
}
```

If you want to give the trampolined function the name you used before, then you need a different name for the recursive one. You break the recursive function if you replace the function it calls in the recursion. For real recursion, the `Recall` function solves the issue, but unfortunately `Recall` doesn’t give you the current function, it just gives you a way to call it. I don’t know if you can get hold of the function you are currently executing, so if you do, please tell me. Then I don’t have to figure it out, and my curiosity is already killing me.

To get a trampoline version of the tree size function, you replace all recursive calls with a corresponding `make_thunk` call. You *also* have to replace all calls to the continuation with a `make_thunk`. Otherwise, while the recursion will not exceed the stack space, the continuation calls will.


```r
tree_size_rec <- function(tree, cont = identity) {
    cases(tree,
          Leaf(.) -> make_thunk(cont, 1),
          Tree(left, right) -> {
              go_right <- function(left_res) {
                  add_results <- function(right_res)
                      make_thunk(cont, left_res + right_res + 1)
                  make_thunk(tree_size_rec, right, add_results)
              }
              make_thunk(tree_size_rec, left, go_right)
          })
}
tree_size <- trampoline(tree_size_rec)
```



Getting the insertion function to use thunks and trampolines is just as simple. Just follow the same rules.


```r
insert_rec <- function(tree, key, cont = identity) {
    cases(tree,
          STEmpty -> make_thunk(cont, ST(STEmpty, key, STEmpty)),
          ST(left, k, right) -> {
              right_cont <- function(res) ST(left, k, res)
              left_cont <- function(res) ST(res, k, right)

              if (k < key) make_thunk(insert_rec, right, key, right_cont)
              else if (k > key) make_thunk(insert_rec, left, key, left_cont)
              else make_thunk(cont, ST(left, key, right))
          }
    )
}
insert <- trampoline(insert_rec)
```



Using thunks and trampolines is not going to make your code run faster. Quite the opposite. But it does solve the problem with exceeding the stack space.

You can solve the same problem and get better performance as well using iterative functions. It is just a lot harder to implement. And, while you might not consider continuation passing and thunks to be simple and clear code, it is better than what you would get out of a looping version in most cases.


