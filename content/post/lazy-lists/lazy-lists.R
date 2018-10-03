library(pmatch)

linked_list := NIL | CONS(car, cdr)
toString.linked_list <- function(llist)
  cases(llist, NIL -> "[]",
        CONS(car, cdr) -> paste(car, "::", toString(cdr)))
print.linked_list <- function(llist)
  cat(toString(llist), "\n")

# lazy lists are thunks
make_delay_thunk <- function(expr) {
  structure(function() expr, class = "lazy_list")
}
make_lazy_thunk <- function(expr) {
  force(expr)
  structure(function() expr, class = "lazy_list")
}
toString.lazy_list <- function(x)
  cases(x(),
        NIL -> "<>",
        CONS(car, cdr) -> paste(car, ":: <...>"))
print.lazy_list <- function(x)
  cat(toString(x), "\n")

lazy_nil   <- make_lazy_thunk(NIL)
lazy_cons  <- function(car, cdr) make_lazy_thunk(CONS(car, cdr))
delay_cons <- function(car, cdr) make_delay_thunk(CONS(car, cdr))

lazy <- lazy_cons(make_noise(1), lazy_cons(make_noise(2), lazy_nil()))
delayed <- delay_cons(make_noise(1), delay_cons(make_noise(2), lazy_nil()))

lazy
delayed

lazy_to_llist <- function(x) {
  cases(x(),
        NIL -> NIL,
        CONS(car, cdr) -> CONS(car, lazy_to_llist(cdr)))
}

x <- purrr::reduce(1:5, ~ lazy_cons(.y, .x), .init = lazy_nil())
x
lazy_to_llist(x)


cases(x(),
      NIL -> NIL,
      CONS(car, cdr) -> CONS(car, lazy_to_llist(cdr)))



lazy_macro <- function(empty_pattern, nonempty_pattern, ...) {

  empty_pattern    <- substitute(empty_pattern)
  nonempty_pattern <- substitute(nonempty_pattern)
  extra_args <- rlang::enexprs(...)

  cases_pattern <- rlang::expr(
    cases(.list,
          LLNIL -> !!empty_pattern,
          DELAYED(.list_thunk) ->
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

lazy_nil   <- make_thunk(NIL, "lazy_list")
lazy_cons  <- function(car, cdr) make_thunk(CONS(car, cdr), "lazy_list")
delay_cons <- function(car, cdr) make_lazy_thunk(CONS(car, cdr), "lazy_list")

lazy_to_llist <- function(lazy)
  cases(lazy(),
        NIL -> NIL,
        CONS(car, cdr) -> CONS(car, lazy_to_llist(cdr)))

x <- purrr::reduce(1:5, ~ lazy_cons(.y, .x), .init = lazy_nil)
x
lazy_to_llist(x)


make_noise <- function(val) {
  cat("I see", val, "\n")
  val
}
y <- delay_cons(make_noise(1), delay_cons(make_noise(2), lazy_nil))

lazy_car <- function(lst) lst()$car
lazy_cdr <- function(lst) lst()$cdr

lazy_car(y)
lazy_car(y)
lazy_cdr(y)
lazy_car(lazy_cdr(y))
lazy_cdr(lazy_cdr(y))

lazy_length <- function(llist, acc = 0)
  cases(llist(),
        NIL -> acc,
        CONS(., cdr) -> lazy_length(cdr, acc + 1))

lazy_length(x)
lazy_length(y)

z <- delay_cons(make_noise(5), delay_cons(make_noise(6), lazy_nil))
lazy_length(z)
lazy_length(z)

lazy_concat <- function(l1, l2) {
  cases(l1(),
        NIL -> l2,
        CONS(car, cdr) -> delay_cons(car, lazy_concat(cdr, l2)))
}

y <- delay_cons(make_noise(1), delay_cons(make_noise(2), lazy_nil))
z <- delay_cons(make_noise(5), delay_cons(make_noise(6), lazy_nil))

lazy_concat(y, z)
lazy_concat(y, z)

y <- delay_cons(make_noise(1), delay_cons(make_noise(2), lazy_nil))
lazy_length(y)
lazy_concat(y, z)


lazy_to_llist(y)
lazy_to_llist(z)
lazy_to_llist(lazy_concat(y, z))

lazy_reverse <- function(lazy, acc = lazy_nil)
  cases(lazy(),
        NIL -> acc,
        CONS(car, cdr) -> lazy_reverse(cdr, lazy_cons(car, acc)))

lazy_to_llist(x)
lazy_to_llist(lazy_reverse(x))

y <- delay_cons(make_noise(1), delay_cons(make_noise(2), lazy_nil))
lazy_reverse(y)

y <- delay_cons(make_noise(1), delay_cons(make_noise(2), lazy_nil))
z <- delay_cons(make_noise(6), delay_cons(make_noise(4), lazy_nil))
yy <- lazy_concat(y, lazy_reverse(z))
lazy_to_llist(yy)
lazy_to_llist(yy)

