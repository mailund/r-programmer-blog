---
title: "Update Is Not Update"
date: 2019-04-02T20:34:37+02:00
---

I ran into this little problem yesterday and thought I would share it. I needed to collect a bunch of items into a list, and I needed to do that from several functions that functioned as callbacks.

Ok, that sounds abstract, so let me make it simple. I had a list

```r
my_items <- list()
```

and one or more functions that should update it

```r
f1 <- function(elm) {
  # add elm to my_item
}
f2 <- function(elm) {
  # add elm to my_item
}
…
fn <- function(elm) {
  # add elm to my_item
}
```

It was slightly more complicated because I didn’t want to use a global variable for `my_items` and so I wrapped all the functions in a (closure) scope, but there is no need for the added complexity here.

First, I did what you should never do and concatenated the list with the new element.

```r
f1 <- function(elm) {
    my_items <<- c(my_items, elm)
}
```

I know that it is inefficient but it is easy to program, and if the list never gets long the performance is fine.^[Also, I didn’t think too hard about it. The efficient way to append isn’t complicated either, it is just not as readily available in my brain.]

The performance wasn’t fine.

So I had to change append code.

Before we get to that, however, I want to draw your attention to the assignment here. The assignment operator is `<<-`. If it was `<-` I would create a local reference to the list `c(my_items, elm)` and I would *not* update the global variable.

Let that be a hint for what happens next…

If you want to append to a list then 

```r
 <-  elm
```

is the way to do it. You get amortised constant time appends this way (instead of linear time appends with `c()`).

So, this looks reasonable, right?

```r
f1 <- function(elm) {
    my_list[[length(my_list) + 1]] <- elm
}
```

It *does* look reasonable, but the problem is the `<-` assignment. It is less obvious here because we are updating the global variable and not assigning to a local variable, except that is exactly what we are doing.

When you update data in R, as a general rule, what you are actually doing is making a copy of the data with the modifications and then assigning the result back to the reference you have to the data.

The assignment here calls the `[[<-` function. When you assign to a function call (and `[[` is a function call) a `<-` version of the function is called to produce updated values. The updated version is written to the variable you used. So what happens in my assignment from above is this. I get the global lest, then I modify it—which always means that I produce a new modified copy—and then I assign the result back to `my_list`. This, however, will be a new local variable. Even though I am modifying a list from a global variable, the way R handles indexing (and all `<-` functions) gives me a local variable.

The right solution, of course, is this:

```r
f1 <- function(elm) {
    my_list[[length(my_list) + 1]] <<- elm
}
```
