# Helpers for driving the HTTP layer from a test without a running server.
#
# The package talks to LM Studio through httr2::req_perform(). These helpers
# replace that call for the duration of one test, record every request the code
# under test sends, and answer each one with a response the test builds itself.

# Build a synthetic httr2 response. `body` is the response body as a string.
# An empty string means the response carries no body at all.
mock_response <- function(status_code = 200L, body = "{}") {
  httr2::response(
    status_code = status_code,
    body = if (identical(body, "")) raw(0) else charToRaw(body),
    headers = list(`Content-Type` = "application/json")
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

# Read the HTTP method and path a captured request would send. httr2 infers the
# method from the presence of a body rather than storing it on the request, so
# req_dry_run() is what reports the verb. That call needs httpuv, which is a
# suggested package, so a machine without it skips the calling test rather than
# failing it.
request_target <- function(req) {
  testthat::skip_if_not_installed("httpuv")
  out <- httr2::req_dry_run(req, quiet = TRUE)
  list(method = out$method, path = out$path)
}
