# Helpers for driving the HTTP layer from a test without a running server.
#
# The package talks to LM Studio through httr2::req_perform(). These helpers
# replace that call for the duration of one test, record every request the code
# under test sends, and answer each one with a response the test builds itself.

# Build a synthetic httr2 response. `body` is the response body as a string.
# An empty string means the response carries no body at all. `content_type`
# sets the header the body is served under, so a test can send a body httr2
# refuses to parse as JSON on the header alone.
mock_response <- function(
  status_code = 200L,
  body = "{}",
  content_type = "application/json"
) {
  httr2::response(
    status_code = status_code,
    body = if (identical(body, "")) raw(0) else charToRaw(body),
    headers = list(`Content-Type` = content_type)
  )
}

# Mock httr2::req_perform() for the calling test and return a recorder. Read the
# captured requests from `recorder$requests`, in the order they were sent. Every
# request gets the same `response`.
local_request_recorder <- function(
  response = mock_response(),
  .env = parent.frame()
) {
  local_mock_perform(function(n) response, .env = .env)
}

# Mock httr2::req_perform() like local_request_recorder(), but answer the
# first request with `responses[[1]]`, the second with `responses[[2]]`, and so
# on. A request past the end of the list raises, so a test that sends more
# requests than it planned for fails rather than reusing a reply.
local_request_sequence <- function(responses, .env = parent.frame()) {
  local_mock_perform(
    function(n) {
      if (n > length(responses)) {
        stop(
          "request ", n, " arrived, but only ", length(responses),
          " responses were given",
          call. = FALSE
        )
      }
      responses[[n]]
    },
    .env = .env
  )
}

# The shared body of the two recorders above. `respond` takes the position of
# the request, counted from 1, and returns the response to serve.
local_mock_perform <- function(respond, .env) {
  recorder <- new.env(parent = emptyenv())
  recorder$requests <- list()

  perform <- function(req, ...) {
    recorder$requests[[length(recorder$requests) + 1L]] <- req
    response <- respond(length(recorder$requests))

    # Apply the request's own error policy, the way req_perform() does. Without
    # this, a caller that drops its req_error() line still sees every mocked
    # response returned rather than thrown, and no test can tell.
    is_error <- req$policies$error_is_error
    if (is.null(is_error)) {
      is_error <- function(resp) httr2::resp_status(resp) >= 400
    }
    if (isTRUE(is_error(response))) {
      httr2::resp_check_status(response)
    }

    response
  }

  testthat::local_mocked_bindings(
    req_perform = perform,
    .package = "httr2",
    .env = .env
  )

  recorder
}

# Read what a captured request would actually send: the HTTP method, the path,
# the host header, and the request body. httr2 infers the method from the
# presence of a body rather than storing it on the request, so req_dry_run() is
# what reports the verb. The same call is what reports the headers and the
# serialized body, so an assertion made here is an assertion about the bytes
# that go over the wire rather than about a field of the request object.
#
# `host` is the host header as httr2 sends it, so it carries no URL scheme:
# a request built for "http://example.com:9999" reports "example.com:9999".
#
# `body` is the serialized body parsed back from JSON, or NULL when the request
# carries no body. A body that is not valid JSON comes back as its text, one
# character string. jsonlite::validate() decides which, so a text that is not
# JSON never reaches jsonlite::fromJSON(), which reads a URL or a file name as
# a place to fetch.
#
# Decide what a test should do when httpuv is missing. req_dry_run() needs
# httpuv, which is a suggested package, so a bare machine skips the calling
# test rather than failing it. Under CI httpuv is expected to be there, so a
# skip would let every assertion that reads a request pass by not running, and
# nobody would see it. The check workflows install Suggests, which lists
# httpuv; the source-tree tests workflow gets it through devtools instead, so a change
# to either one can take it away silently. Failing is what makes that visible.
# Returns one of "run", "fail", or "skip".
#
# Both inputs are arguments so a test can drive either branch without mocking
# requireNamespace() or setting a variable for the whole session.
httpuv_absence_action <- function(
  installed = requireNamespace("httpuv", quietly = TRUE),
  ci = Sys.getenv("CI")
) {
  if (isTRUE(installed)) {
    return("run")
  }
  if (nzchar(ci)) {
    return("fail")
  }
  "skip"
}

# Act on the decision above. Returns invisibly when the caller may proceed,
# raises when httpuv is missing under CI, and skips the calling test otherwise.
require_httpuv <- function(action = httpuv_absence_action()) {
  if (identical(action, "run")) {
    return(invisible(TRUE))
  }
  if (identical(action, "fail")) {
    stop(
      "httpuv is not installed and CI is set. ",
      "Every request assertion would pass by not running.",
      call. = FALSE
    )
  }
  testthat::skip("httpuv is not installed")
}

# `headers` is the request's headers as they go over the wire. A secret header,
# such as Authorization, holds an httr2 object of class
# "httr2_redacted_sentinel" in place of its value, unless the caller passes
# `redact_headers = FALSE`. A failure then prints a token only in a test that
# asks for it. Names arrive lowercased, so read `headers$authorization` rather
# than the sent spelling.
request_target <- function(req, redact_headers = TRUE) {
  out <- request_dry_run(req, redact_headers = redact_headers)
  body <- NULL
  if (length(out$body) > 0L) {
    text <- rawToChar(out$body)
    body <- if (jsonlite::validate(text)) jsonlite::fromJSON(text) else text
  }
  list(
    method = out$method,
    path = out$path,
    host = out$headers$host,
    headers = out$headers,
    body = body
  )
}

# The body text a captured request sends, unparsed, so a test can compare it
# byte for byte with a jsonlite write. The old httr2 1.3.0 writer,
# req_body_json(), rebuilt the body when the request was dry-run, and a
# POSIXlt value there recursed with no end. So the dry run gets `seconds` and
# then fails, and a red run on the old writer ends. The dry-run helper makes up
# to 5 tries, and each try gets one sixth of `seconds`, 5 at most. So every try
# ends before the limit does. A limit that fires inside the dry run can halt R.
request_body_text <- function(req, seconds = 30) {
  setTimeLimit(elapsed = seconds, transient = TRUE)
  on.exit(setTimeLimit(elapsed = Inf), add = TRUE)
  out <- request_dry_run(
    req,
    redact_headers = FALSE,
    tries = 5L,
    seconds = min(5, seconds / 6)
  )
  rawToChar(out$body)
}

# Dry-run `req` and return what httr2::req_dry_run() reports. Every test that
# reads a request goes through here. With curl 8.0.0 and httr2 1.3.0,
# req_dry_run() calls curl::curl_echo(). That function takes a port from
# find_port(), which shuffles 1024:49151 with sample() on each call. It starts
# an echo server on 0.0.0.0 at that port and sends the request to 127.0.0.1
# there. A program that listens on 127.0.0.1 alone at that port does not stop
# find_port(), and on macOS the echo server binds too. The request then goes
# to that program. If it answers in HTTP, the result holds no method, path, or
# body. If it closes the connection, sends text that is not HTTP, or never
# replies, the dry run stops with a curl error. Each try gets `seconds`, so a
# program that never replies ends the try with curl's timeout error. If the
# echo server cannot bind, the dry run stops with httpuv's "Failed to create
# server". In each case this helper tries again on a new port. A request that
# curl cannot send, such as a URL with a space in its path, also gives a curl
# error, on every try. So after `tries` tries, the stop message names the
# likely cause and keeps the last error. No other error is caught.
request_dry_run <- function(req, redact_headers = TRUE, tries = 5L,
                            seconds = 5) {
  require_httpuv()
  req <- httr2::req_timeout(req, seconds)
  last_error <- NULL
  for (i in seq_len(tries)) {
    out <- tryCatch(
      httr2::req_dry_run(req, quiet = TRUE, redact_headers = redact_headers),
      error = function(cnd) {
        if (!inherits(cnd, "curl_error") &&
          !identical(conditionMessage(cnd), "Failed to create server")) {
          stop(cnd)
        }
        last_error <<- cnd
        NULL
      }
    )
    if (!is.null(out$method)) {
      return(out)
    }
  }
  stop(
    "The dry run received no request in ", tries,
    if (tries == 1L) " try. " else " tries. ",
    "Another program probably listens on 127.0.0.1 at the port that ",
    "curl::curl_echo() picked.",
    if (!is.null(last_error)) {
      paste0(" The last try ended with this error: ", conditionMessage(last_error))
    },
    call. = FALSE
  )
}

# Mock httr2::req_perform() for the calling test so that any request at all
# raises. A guard that runs before the request is what these tests are about,
# so a request reaching this mock is the failure they exist to catch.
local_no_request_allowed <- function(.env = parent.frame()) {
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      stop("a request left the process", call. = FALSE)
    },
    .package = "httr2",
    .env = .env
  )
}

# A server probe that reports a stopped server and counts its calls. A test
# that reaches it gets `rlmstudio_no_server`, and the count says so even where
# `expect_error()` would accept that condition (LESSONS, M015). No request may
# leave the process.
local_counting_probe <- function(.env = parent.frame()) {
  probe <- new.env(parent = emptyenv())
  probe$calls <- 0L
  testthat::local_mocked_bindings(
    is_server_running = function(...) {
      probe$calls <- probe$calls + 1L
      FALSE
    },
    .env = .env
  )
  local_no_request_allowed(.env = .env)
  probe
}
