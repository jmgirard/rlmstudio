# lms_server_ready() answers one question: does this host answer as a usable
# LM Studio server? The cases below run from nothing listening at all to a
# real model list.
#
# The first three cases use a real TCP target, because a refused connection
# and a silent listener are properties of the socket. The rest mock the
# transport through the shared recorder, because an HTTP status and a body
# shape are properties of the response.

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
  # What this bound can and cannot catch. httr2 and curl set no default
  # timeout, so a version of the function with the req_timeout() line deleted
  # hangs on this socket rather than failing here: the suite stops instead of
  # going red. The bound does catch a timeout that is set but wrong, such as a
  # hardcoded minute in place of the argument.
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

test_that("a failed status is not ready even when the body looks right", {
  # This is what makes the status check discriminate. The 401 case above sends
  # a body with no `models` key, so it returns FALSE through the body test
  # whether or not the status is read. Here the body would pass on its own, so
  # deleting the status check turns this test red.
  for (status in c(401L, 500L)) {
    local_request_recorder(
      mock_response(status, '{"models": [{"type": "llm", "key": "a", "loaded_instances": []}]}')
    )
    expect_identical(lms_server_ready(), FALSE)
  }
})

test_that("a 200 whose body carries no model list is not ready", {
  local_request_recorder(mock_response(200L, '{"object": "list"}'))

  expect_identical(lms_server_ready(), FALSE)
})

test_that("a 200 whose body carries a model list is ready", {
  local_request_recorder(
    mock_response(200L, '{"models": [{"type": "llm", "key": "a", "loaded_instances": []}]}')
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

test_that("an array that is not an array of models is not a model list", {
  # A real model list holds one JSON object per model. An array of bare
  # strings or numbers under the same key is a different server answering, and
  # telling those apart is what this function is for.
  for (body in c('{"models": ["a", "b"]}', '{"models": [1, 2, 3]}')) {
    local_request_recorder(mock_response(200L, body))
    expect_identical(lms_server_ready(), FALSE)
  }
})

test_that("a model list of several models is ready", {
  local_request_recorder(
    mock_response(
      200L,
      '{"models": [{"type": "llm", "key": "a", "loaded_instances": []}, {"type": "llm", "key": "b", "loaded_instances": []}]}'
    )
  )
  expect_identical(lms_server_ready(), TRUE)
})

test_that("each token source reaches the Authorization header", {
  # Four sources, four distinct values. The first two cases fill the sources
  # below the one under test with decoy values, so a wrapper that reaches past
  # its argument sends a string that names the source it leaked from. The last
  # two cases clear the sources that would otherwise win instead, because for
  # the environment variable and for no token there is no decoy that a correct
  # result could be told apart from. request_target() reads headers with
  # redaction off, so a failure prints the literal value.
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

# A fault in the call is not a fact about the server, so it aborts rather
# than reporting FALSE. The help page names these six and says which package
# each message comes from, so each message text is pinned here. A message
# that moves under a dependency update turns these red, which is the point:
# the page would otherwise quote text the packages no longer produce.

test_that("a host of NULL aborts rather than reporting FALSE", {
  expect_error(
    lms_server_ready(host = NULL),
    "`url` must be a single string, not `NULL`"
  )
})

test_that("a host of more than one string aborts", {
  expect_error(
    lms_server_ready(host = c("http://a:1", "http://b:2")),
    "`url` must be a single string, not a character vector"
  )
})

test_that("a host that is a character NA aborts", {
  expect_error(
    lms_server_ready(host = NA_character_),
    "`url` must be a single string, not a character `NA`"
  )
})

test_that("a host that is not one string aborts whatever the reason", {
  # The page says the six it names are not the whole list. These three are
  # the examples it gives, so their messages are pinned too.
  expect_error(
    lms_server_ready(host = 1),
    "`url` must be a single string, not the number 1"
  )
  expect_error(
    lms_server_ready(host = list("a")),
    "`url` must be a single string, not a list"
  )
  expect_error(
    lms_server_ready(host = character(0)),
    "`url` must be a single string, not an empty character vector"
  )
})

test_that("a host that cannot be parsed as a URL aborts", {
  # curl names the reason, so the page quotes two of them rather than one.
  expect_error(
    lms_server_ready(host = "http://exa mple:1234"),
    "Failed to parse URL: Malformed input to a URL function"
  )
  expect_error(
    lms_server_ready(host = ""),
    "Failed to parse URL: No host part in the URL"
  )
})

test_that("a timeout below one millisecond aborts", {
  expect_error(
    lms_server_ready(timeout = 0.0005),
    "`seconds` must be >1 ms"
  )
})

test_that("a timeout that is not one number aborts", {
  expect_error(
    lms_server_ready(timeout = "2"),
    '`seconds` must be a number, not the string "2"'
  )
  # The page says the message names either the value or its type. A string
  # gets the value, a vector of two gets the type.
  expect_error(
    lms_server_ready(timeout = c(1, 2)),
    "`seconds` must be a number, not a double vector"
  )
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
