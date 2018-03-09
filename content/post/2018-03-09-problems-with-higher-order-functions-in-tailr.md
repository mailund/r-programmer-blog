---
title: Problems With Higher Order Functions in tailr
date: 2018-03-09T18:38:52+01:00
tags:
    - tailr
categories:
    - Metaprogramming
---

Ok, there is a problem with higher-order functions in my [`tailr` package](https://github.com/mailund/tailr) that I ran into while writing linked list functions for my [`matchbox` package](https://github.com/mailund/matchbox).^[Thanks again to Dmytro Perepolkin for suggesting the name.]

If you write a tail-recursive function that uses a parameter-function, the `tailr` package will complain that it doesn't see that function in scope. This is correct, but only because I do not check the formal arguments of the recursive function.

Consider this example, that involves a perfectly valid tail-recursive function for mapping over a linked list:

```r
library(pmatch)

 llist := NIL | CONS(car, cdr:llist)

llrev <- function(llist, acc = NIL) {
    pmatch::cases(
        llist,
        NIL -> acc,
        CONS(car, cdr) -> llrev(cdr, CONS(car, acc))
    )
}
llrev <- tailr::loop_transform(llrev)

llmap <- function(llist, f, acc = NIL) {
    pmatch::cases(
        llist,
        NIL -> llrev(acc),
        CONS(car, cdr) -> llmap(cdr, f, CONS(f(car), acc))
    )
}
```

Trying to transform `llmap` will give you an error because `tailr` can't find `f`.

I've put that on the [todo list](https://github.com/mailund/tailr/issues/19) and it should be easy enough to fix. I just have to pass the function along to all the function calls so I can get at the `formals()`. I tried to fix it quickly, but changing the functions break everything, so I will have to do it when I have more time for it.


