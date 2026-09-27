# The port helpers in helper-ports.R pick ports for the tests that need a real
# TCP socket. They must not touch the session's random number generator: a
# helper that calls sample() moves .Random.seed for every later test, and under
# a fixed seed it tries the same ports on every run.

# Run `call` and report whether .Random.seed is the same object afterwards.
seed_after <- function(call) {
  withr::local_seed(1)
  before <- get(".Random.seed", envir = globalenv())
  call()
  identical(get(".Random.seed", envir = globalenv()), before)
}

# Run `call` in a session with no .Random.seed and report whether it is still
# absent afterwards. The seed comes back when the function returns.
seed_absent_after <- function(call) {
  withr::local_preserve_seed()
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    rm(".Random.seed", envir = globalenv())
  }
  call()
  !exists(".Random.seed", envir = globalenv(), inherits = FALSE)
}

test_that("local_listener() leaves the random seed alone", {
  expect_true(seed_after(function() local_listener()))
  expect_true(seed_absent_after(function() local_listener()))
})

test_that("free_port() leaves the random seed alone", {
  expect_true(seed_after(function() free_port()))
  expect_true(seed_absent_after(function() free_port()))
})

test_that("two open listeners get different ports", {
  first <- local_listener()
  second <- local_listener()
  expect_false(first == second)
  expect_true(is_server_running(paste0("http://127.0.0.1:", first)))
  expect_true(is_server_running(paste0("http://127.0.0.1:", second)))
})

test_that("free_port() returns a port that nothing listens on", {
  port <- free_port()
  expect_false(is_server_running(paste0("http://127.0.0.1:", port)))
})

test_that("each helper fails when no port in its range binds", {
  held <- local_listener()
  expected <- paste0("No free port in ", held, "-", held, " (1 tried).")
  expect_error(local_listener(ports = held), expected, fixed = TRUE)
  expect_error(free_port(ports = held), expected, fixed = TRUE)
})
