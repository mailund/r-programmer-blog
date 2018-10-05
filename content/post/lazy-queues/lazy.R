
lazy_thunk <- function(expr) function() expr

x <- 3
f <- function() {
  cat("evaluating f\n")
  x
}
g <- function(x) {
  cat("evaluating g\n")
  x
}
lt_f <- lazy_thunk(f())
lt_g <- lazy_thunk(g(x))

x <- 4
lt_f()
lt_g()
x <- 5
lt_f()
lt_g()
x <- 6
lt_f()
lt_g()


