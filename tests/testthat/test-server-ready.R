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

test_that("a port held by something else passes the TCP probe and fails here", {
  # This is the gap the condition help page now names. The TCP probe reads the
  # port and nothing else, so a listener that is not LM Studio suppresses the
  # `rlmstudio_no_server` condition. The readiness check is what tells them
  # apart.
  listener <- open_listener()
  on.exit(close(listener$con), add = TRUE)
  host <- paste0("http://127.0.0.1:", listener$port)

  expect_true(is_server_running(host))
  expect_silent(stop_if_no_server(host))
  expect_identical(lms_server_ready(host = host, timeout = 1), FALSE)
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

test_that("each token source reaches the Authorization header", {
  # Four sources, four distinct values. Each case unsets the two sources below
  # it, so a value that arrives could only have come from the source named.
  # request_target() reads headers with redaction off, so a failure prints the
  # literal value and names the source that leaked.
  cases <- list(
    list(
      source = "argument",
      expected = "Bearer ready-argument",
      run = function() {
        withr::local_envvar(RLMSTUDIO_API_TOKEN = "ready-envvar")
        withr::local_options(rlmstudio.token = "ready-option")
        lms_server_ready(token = "ready-argument")
      }
    ),
    list(
      source = "option",
      expected = "Bearer ready-option",
      run = function() {
        withr::local_envvar(RLMSTUDIO_API_TOKEN = "ready-envvar")
        withr::local_options(rlmstudio.token = "ready-option")
        lms_server_ready()
      }
    ),
    list(
      source = "environment variable",
      expected = "Bearer ready-envvar",
      run = function() {
        withr::local_envvar(RLMSTUDIO_API_TOKEN = "ready-envvar")
        withr::local_options(rlmstudio.token = NULL)
        lms_server_ready()
      }
    ),
    list(
      source = "no token",
      expected = NULL,
      run = function() {
        withr::local_envvar(RLMSTUDIO_API_TOKEN = "")
        withr::local_options(rlmstudio.token = NULL)
        lms_server_ready()
      }
    )
  )

  for (case in cases) {
    recorder <- local_request_recorder(mock_response(200L, '{"models": []}'))
    case$run()

    expect_length(recorder$requests, 1L)
    expect_identical(
      request_target(recorder$requests[[1]])$headers$authorization,
      case$expected,
      info = case$source
    )
  }
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
