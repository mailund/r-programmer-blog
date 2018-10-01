
library(pmatch)

linked_list := NIL | CONS(car, cdr : linked_list)

llist <- purrr::reduce_right(1:6, ~ CONS(.y,.x), .init = NIL)
llist

toString.linked_list <- function(llist)
  cases(llist, NIL -> "[]",
        CONS(car, cdr) -> paste(car, "::", toString(cdr)))
print.linked_list <- function(llist)
  cat(toString(llist), "\n")

llist

concat <- function(l1, l2)
  cases(l1,
        NIL -> l2,
        CONS(car, cdr) -> CONS(car, concat(cdr, l2)))
concat(llist, llist)

reverse <- function(llist, acc = NIL)
  cases(llist,
        NIL -> acc,
        CONS(car, cdr) -> reverse(cdr, CONS(car, acc)))
reverse(llist)

queue := QUEUE(front : linked_list, back : linked_list)
print.queue <- function(queue) {
  cat("Front:\t")
  print(queue$front)
  cat("Back:\t")
  print(queue$back)
}

new_queue <- function() QUEUE(NIL, NIL)
enqueue <- function(queue, x)
  cases(queue, QUEUE(front, back) -> QUEUE(front, CONS(x, back)))

queue <- purrr::reduce(1:8, enqueue, .init = new_queue())
queue

pair := PAIR(first, second)
print.pair <- function(pair) {
  cat("First\n")
  print(pair$first)
  cat("Second:\n")
  print(pair$second)
}

move_front_to_back <- function(queue)
  cases(queue, QUEUE(front, back) -> QUEUE(NIL, concat(back, reverse(front))))
move_back_to_front <- function(queue)
  cases(queue, QUEUE(front, back) -> QUEUE(concat(front, reverse(back)), NIL))

queue2 <- move_back_to_front(queue)
queue2
move_front_to_back(queue2)

front <- function(queue)
  cases(queue,
        QUEUE(NIL, NIL)        -> stop("Empty queue"),
        QUEUE(NIL, .)          -> front(move_back_to_front(queue)),
        QUEUE(CONS(car, cdr), back) -> PAIR(car, QUEUE(cdr, back)))

bind[PAIR(first, queue)] <- front(queue)
first
queue

back <- function(queue)
  cases(queue,
        QUEUE(NIL, NIL)        -> stop("Empty queue"),
        QUEUE(., NIL)          -> back(move_front_to_back(queue)),
        QUEUE(front, CONS(car, cdr)) -> PAIR(car, QUEUE(front, cdr)))

bind[PAIR(first, queue)] <- back(queue)
first
queue

queue_to_llist <- function(queue)
  cases(queue,
        QUEUE(NIL, NIL) -> NIL,
        otherwise ->
          cases(front(queue),
                PAIR(x, q) -> CONS(x, queue_to_llist(q))))
queue_to_llist(queue)


queue := QUEUE(front_len, front, back_len, back)
# I need to redefine this since the construct :=
# defines a default that overwrites the one
# we defined above
print.queue <- function(queue) {
  cat("Front length:\t", queue$front_len, "\n")
  cat("Back length:\t", queue$back_len, "\n")
  cat("Front:\t")
  print(queue$front)
  cat("Back:\t")
  print(queue$back)
}

new_queue <- function() QUEUE(0, NIL, 0, NIL)
enqueue <- function(queue, x)
  cases(queue,
        QUEUE(front_len, front, back_len, back) ->
          QUEUE(front_len, front, back_len + 1, CONS(x, back)))

queue <- purrr::reduce(1:8, enqueue, .init = new_queue())
queue

queue_len <- function(queue)
  cases(queue, QUEUE(front_len, ., back_len, .) -> front_len + back_len)

queue_len(queue)

move_front_to_back <- function(queue)
  cases(queue,
        QUEUE(front_len, front, back_len, back) ->
          QUEUE(0, NIL, front_len + back_len, concat(back, reverse(front))))
move_back_to_front <- function(queue)
  cases(queue,
        QUEUE(front_len, front, back_len, back) ->
          QUEUE(front_len + back_len, concat(front, reverse(back)), 0, NIL))

queue <- move_back_to_front(queue)
queue
move_front_to_back(queue)

front <- function(queue)
  cases(queue,
        QUEUE(., NIL, ., NIL)        -> stop("Empty queue"),
        QUEUE(., NIL, ., .)          -> front(move_back_to_front(queue)),
        QUEUE(front_len, CONS(car, cdr), back_len, back) ->
          PAIR(car, QUEUE(front_len - 1, cdr, back_len, back)))

bind[PAIR(first, queue)] <- front(queue)
first
queue

back <- function(queue)
  cases(queue,
        QUEUE(., NIL, ., NIL)        -> stop("Empty queue"),
        QUEUE(., ., ., NIL)          -> back(move_front_to_back(queue)),
        QUEUE(front_len, front, back_len, CONS(car, cdr)) ->
          PAIR(car, QUEUE(front_len, front, back_len - 1, cdr)))

bind[PAIR(first, queue)] <- back(queue)
first
queue


# Now, only move half...
split_list <- function(lst, n, acc = NIL)
  cases(..(n, lst),
        ..(0, lst) -> PAIR(reverse(acc), lst),
        ..(n, CONS(car, cdr)) -> split_list(cdr, n - 1, CONS(car, acc)))

llist
split_list(llist, 3)

move_front_to_back <- function(queue)
  cases(queue,
        QUEUE(front_len, front, 0, NIL) -> {
          n <- floor(front_len / 2)
          cases(split_list(front, n),
                PAIR(first, second) ->
                  QUEUE(n,
                        first,
                        front_len - n,
                        reverse(second)))
          })

move_back_to_front <- function(queue)
  cases(queue,
        QUEUE(0, NIL, back_len, back) -> {
          n <- floor(back_len / 2)
          cases(split_list(back, n),
                PAIR(first, second) ->
                  QUEUE(back_len - n, reverse(second), n, first))
        })


queue_to_llist <- function(queue)
  cases(queue,
        QUEUE(., NIL, ., NIL) -> NIL,
        otherwise ->
          cases(front(queue),
                PAIR(x, q) -> CONS(x, queue_to_llist(q))))

queue_to_llist(queue)

queue <- purrr::reduce(1:8, enqueue, .init = new_queue())
queue
rev_queue <- purrr::reduce(1:8, enqueue_front, .init = new_queue())
rev_queue

queue_to_llist(queue)
queue_to_llist(rev_queue)

reverse_queue_to_llist(queue)
reverse_queue_to_llist(rev_queue)

xx <- function(queue) {
  while (TRUE) {
    cases(queue,
        QUEUE(.,NIL,.,NIL) -> return(),
        otherwise -> NULL)
    bind[x,queue] <- back(queue)
    print(x)
   # print(queue)
  }
}
xx(rev_queue)
