# lms_server_ready() answers one question: does this host answer as a usable
# LM Studio server? The five cases below are the five ways a host can answer,
# from nothing listening at all to a real model list.
#
# The first two cases use a real TCP target. The other three mock the transport
# through the shared recorder, because an HTTP status and a body shape are
# properties of the response and not of the socket.

# Bind a listening socket on a random high port and return both the connection
# and the port it took. The caller closes the connection. A port in use makes
# serverSocket() raise, so the loop retries until one is free.
open_listener <- function() {
  for (i in seq_len(50)) {
    port <- sample(20000:40000, 1)
    con <- tryCatch(serverSocket(port), error = function(e) NULL)
    if (!is.null(con)) {
      return(list(con = con, port = port))
    }
  }
  testthat::skip("no free port found in 50 tries")
}

# A port that nothing listens on. Take one, then give it back, so the number is
# known to have been free a moment ago.
free_port <- function() {
  listener <- open_listener()
  close(listener$con)
  listener$port
}

test_that("a closed port is not ready", {
  port <- free_port()

  expect_identical(
    lms_server_ready(host = paste0("http://127.0.0.1:", port), timeout = 1),
    FALSE
  )
})

test_that("an open port whose listener never answers is not ready", {
  listener <- open_listener()
  on.exit(close(listener$con), add = TRUE)

  started <- Sys.time()
  ready <- lms_server_ready(
    host = paste0("http://127.0.0.1:", listener$port),
    timeout = 1
  )
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))

  expect_identical(ready, FALSE)
  # Without a request timeout this call waits on a socket that will never send
  # a byte, so the bound is what proves the timeout argument load-bearing.
  expect_lt(elapsed, 5)
})

test_that("a server that answers 401 is not ready", {
  local_request_recorder(mock_response(401L, '{"error": "unauthorized"}'))

  expect_identical(lms_server_ready(), FALSE)
})

test_that("a 200 whose body carries no model list is not ready", {
  local_request_recorder(mock_response(200L, '{"object": "list"}'))

  expect_identical(lms_server_ready(), FALSE)
})

test_that("a 200 whose body carries a model list is ready", {
  local_request_recorder(
    mock_response(200L, '{"models": [{"type": "llm", "key": "a"}]}')
  )

  expect_identical(lms_server_ready(), TRUE)
})

test_that("a model list with no models in it is still ready", {
  # A fresh LM Studio install has nothing downloaded. The server works, so the
  # empty list reads as ready. A JSON object under the same key does not: that
  # is a different server answering.
  local_request_recorder(mock_response(200L, '{"models": []}'))
  expect_identical(lms_server_ready(), TRUE)
})

test_that("a JSON object under the models key is not a model list", {
  local_request_recorder(mock_response(200L, '{"models": {"a": 1}}'))
  expect_identical(lms_server_ready(), FALSE)
})

test_that("the probe reads the model list from api/v1/models", {
  recorder <- local_request_recorder(mock_response(200L, '{"models": []}'))

  lms_server_ready(host = "http://example.com:9999")

  expect_length(recorder$requests, 1L)
  target <- request_target(recorder$requests[[1]])
  expect_identical(target$method, "GET")
  expect_identical(target$path, "/api/v1/models")
  expect_identical(target$host, "example.com:9999")
})
