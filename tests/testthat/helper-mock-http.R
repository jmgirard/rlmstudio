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
  recorder <- new.env(parent = emptyenv())
  recorder$requests <- list()

  perform <- function(req, ...) {
    recorder$requests[[length(recorder$requests) + 1L]] <- req

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
# carries no body. Every request this package sends has a JSON body, so the
# parse is safe here; a request whose body is not JSON would fail the parse.
#
# Decide what a test should do when httpuv is missing. req_dry_run() needs
# httpuv, which is a suggested package, so a bare machine skips the calling
# test rather than failing it. Under CI httpuv is expected to be there, so a
# skip would let every assertion that reads a request pass by not running, and
# nobody would see it. The check workflows install Suggests, which lists
# httpuv; the headless workflow gets it through devtools instead, so a change
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

# `headers` is the request's headers as they go over the wire, read with
# redaction turned off so an assertion can see an Authorization value. Names
# arrive lowercased, so read `headers$authorization` rather than the sent
# spelling.
request_target <- function(req) {
  require_httpuv()
  out <- httr2::req_dry_run(req, quiet = TRUE, redact_headers = FALSE)
  list(
    method = out$method,
    path = out$path,
    host = out$headers$host,
    headers = out$headers,
    body = if (length(out$body) == 0L) {
      NULL
    } else {
      jsonlite::fromJSON(rawToChar(out$body))
    }
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
