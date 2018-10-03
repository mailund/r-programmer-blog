
queue := QUEUE(front_len, front, back_len, back)
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
        QUEUE(0, NIL, 0, NIL) -> QUEUE(1, )
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
split_list(llist, 3)

move_front_to_back <- function(queue)
  cases(queue,
        QUEUE(front_len, front, back_len, back) -> {
          n <- ceiling(front_len / 2)
          cases(split_list(front, n),
                PAIR(first, second) ->
                  QUEUE(front_len - n,
                        first,
                        back_len + n,
                        concat(back, reverse(second))))
          })

move_back_to_front <- function(queue)
  cases(queue,
        QUEUE(front_len, front, back_len, back) -> {
          n <- ceiling(back_len / 2)
          cases(split_list(back, n),
                PAIR(first, second) ->
                  QUEUE(front_len + n,
                        concat(front, reverse(first)),
                        back_len - n,
                        second))
        })

queue_to_llist <- function(queue)
  cases(queue,
        QUEUE(., NIL, ., NIL) -> NIL,
        otherwise ->
          cases(front(queue),
                PAIR(x, q) -> CONS(x, queue_to_llist(q))))

queue_to_llist(queue)
