#' Is this value usable as a message string?
#'
#' A message read out of a response body is usable only when it is one
#' character string with something in it. Every other shape, a `NULL`, a list,
#' an empty list, a longer vector, an `NA`, an empty string, or a string of
#' whitespace alone, falls through to the HTTP status.
#'
#' @param x Any value read out of a parsed response body.
#' @return `TRUE` when `x` is a length-one character string that holds
#'   something other than whitespace.
#'
#' The length and `NA` guards are defensive. `api_error_message()` parses
#' through `parse_json_body()` with `simplifyVector = FALSE`, so no response
#' body reaches them: a JSON array arrives as a list rather than as a longer
#' vector. A test through the wrappers cannot fire them while that holds.
#'
#' @noRd
is_message_string <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x))
}

#' Pick the message text out of a failed response
#'
#' Reads at most two values out of the parsed body, `error` and
#' `error$message`, and subsets `error` only after checking that it is a list,
#' because `$` on a plain string raises an error in R. A body that does not
#' parse to a list falls back to the body text, and an empty body falls back to
#' the status.
#'
#' Two callers abort on a response the server did not mark as a failure.
#' `lms_load()` aborts when the status is 200 and the body does not report the
#' model as loaded. `list_models()` aborts on any status other than 200, which
#' includes every status below 400. `HTTP Status 200` tells the first caller
#' nothing, so a response below status 400 falls back to the body text before
#' it falls back to the status.
#'
#' @param resp An httr2 response the caller has decided to abort on.
#' @return One character string: the message text the abort will show.
#'
#' @noRd
api_error_message <- function(resp) {
  status <- httr2::resp_status(resp)
  fallback <- paste("HTTP Status", status)
  body <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")

  parsed <- tryCatch(parse_json_body(resp), error = function(e) NULL)

  if (is.list(parsed)) {
    err <- parsed$error
    if (is_message_string(err)) {
      return(err)
    }
    if (is.list(err) && is_message_string(err$message)) {
      return(err$message)
    }
    if (status < 400L && is_message_string(body)) {
      return(body)
    }
    return(fallback)
  }

  if (is_message_string(body)) body else fallback
}

#' Abort on a failed REST response
#'
#' The one abort path for every REST wrapper that handles a failed response.
#' The condition carries the class `rlmstudio_api_error` so callers can catch
#' an API failure by class, and a `status` field holding the response status as
#' an integer.
#'
#' A response with status 401 or 403 means the server refused the call on
#' authentication grounds, so the abort adds a hint. The hint that fits depends
#' on whether the request carried a token, which is why the caller reports it.
#' The caller reports a flag rather than the token itself, so the value never
#' reaches the function that builds the user-facing message.
#'
#' @param resp An httr2 response the caller has decided to abort on.
#' @param label Character. The calling wrapper's own label, which opens the
#'   message.
#' @param token_sent Logical. Whether the request that produced `resp` carried
#'   an API token.
#' @return Never returns. Always aborts.
#'
#' @noRd
rlm_abort_api <- function(resp, label, token_sent = FALSE) {
  msg <- api_error_message(resp)
  status <- as.integer(httr2::resp_status(resp))

  body <- c("x" = "{label}: {msg}")
  if (status %in% c(401L, 403L)) {
    body <- c(body, "i" = api_error_hint(token_sent))
  }

  cli::cli_abort(
    body,
    class = "rlmstudio_api_error",
    status = status,
    call = NULL
  )
}

#' Abort on a response the wrapper cannot interpret
#'
#' The abort path for a response the server did not mark as a failure and that
#' the wrapper still cannot read. The condition carries the class
#' `rlmstudio_bad_response` so callers can catch it apart from
#' `rlmstudio_api_error`, which means a response the server itself reported as
#' a failure, and a `status` field holding the response status as an integer.
#'
#' `rlm_abort_api()` cannot serve this case. On a status below 400 it falls
#' back to the whole body text, which for an embeddings response is every
#' number of every vector, and it has no place to put the advice that follows
#' (D-007).
#'
#' @param resp An httr2 response the caller has decided to abort on.
#' @param label Character. The calling wrapper's own label, which opens the
#'   message.
#' @param detail Character. One clause naming what the body got wrong.
#' @param hint Character. The advice line that follows the clause. The default
#'   points at `simplify = FALSE`, which is right for every fault found after
#'   the body has parsed. A caller whose fault is the parse itself passes its
#'   own hint, because `simplify = FALSE` cannot help there.
#' @param ... Extra fields for the condition, passed on by name. A field given
#'   as `NULL` is kept, so a caller can test for it with `names()`.
#' @return Never returns. Always aborts.
#'
#' @noRd
rlm_abort_bad_response <- function(
  resp,
  label,
  detail,
  hint = paste(
    "The server returned a response this package cannot read.",
    "Call again with {.code simplify = FALSE} to get the body unchanged."
  ),
  ...
) {
  cli::cli_abort(
    c("x" = "{label}: {detail}", "i" = hint),
    class = "rlmstudio_bad_response",
    status = as.integer(httr2::resp_status(resp)),
    ...,
    call = NULL
  )
}

#' Abort on a model-management reply with the wrong shape
#'
#' `list_models()`, `lms_load()`, `lms_download()`, and
#' `lms_download_status()` have no `simplify` argument, so the default hint of
#' `rlm_abort_bad_response()` does not apply to them. This hint names the kind
#' of reply instead.
#'
#' @param resp An httr2 response with status 200.
#' @param label Character. The calling wrapper's own label.
#' @param detail Character. One clause naming the fault.
#' @param what Character. The kind of reply, such as `"a load reply"`.
#' @return Never returns. Always aborts.
#'
#' @noRd
rlm_abort_bad_reply <- function(resp, label, detail, what) {
  rlm_abort_bad_response(
    resp,
    label,
    detail,
    hint = paste(
      "The server returned", what, "this package cannot read.",
      "Something other than LM Studio may be answering on this host."
    )
  )
}

#' Parse a response body as JSON text
#'
#' The one parse for the body of every HTTP reply. It reads the body as UTF-8
#' text and hands it to `jsonlite::parse_json()`, which reads JSON text and
#' nothing else. `jsonlite::fromJSON()`, which `httr2::resp_body_json()`
#' calls, treats a text that is not valid JSON as a place to read from. It
#' fetches a text that starts with `http://` or `https://` and reads a text
#' that names an existing file. A reply body is text the package did not
#' write, so it must not decide which file the package reads or which host it
#' calls (D-016).
#'
#' The header is not checked, so a body is read by its content alone.
#'
#' @param resp An httr2 response.
#' @param simplifyVector Logical. `FALSE` keeps every JSON array a list.
#'   `TRUE` simplifies arrays to vectors and data frames, as
#'   `jsonlite::fromJSON()` does by default.
#' @return The parsed body. Raises the httr2 or jsonlite error when the body
#'   is empty or does not parse.
#'
#' @noRd
parse_json_body <- function(resp, simplifyVector = FALSE) {
  jsonlite::parse_json(
    httr2::resp_body_string(resp, "UTF-8"),
    simplifyVector = simplifyVector
  )
}

#' Parse a successful response body, or abort
#'
#' The parse that a wrapper runs on a status-200 body before it reads it.
#' `lms_server_ready()` is the one wrapper reading such a body that does not
#' use it: that function calls `parse_json_body()` itself and returns `FALSE`
#' on any error. A 200 whose body is not JSON at all reaches here: a proxy or a captive
#' portal answering on the host serves an HTML page under a success status.
#' Left unguarded, httr2 or the jsonlite lexer raises an unclassed error, and
#' a chat batch loses every reply so far to one input. The abort runs before
#' the caller's `simplify` branch, so `simplify = FALSE` cannot rescue the
#' body, and the hint says something the caller can act on instead.
#'
#' The body is parsed by `parse_json_body()`, which reads it by content and not
#' by its `Content-Type` header. A header check would make the same error
#' cover two different causes: a body that will not parse, and a body that
#' parses perfectly under a content type httr2 declines to read. A proxy that
#' rewrites the header to `text/plain` sends good JSON, and reporting that as a
#' parse failure names the wrong fault and leaves no way through. Parsing by
#' content leaves the parse failure as the only cause the abort can have.
#'
#' The message leaves out the parse error, because jsonlite quotes the body
#' text around the point where it stopped.
#'
#' @param resp An httr2 response with status 200.
#' @param label Character. The calling wrapper's own label, which opens the
#'   message.
#' @param ... Extra fields for the condition, passed on to
#'   `rlm_abort_bad_response()`.
#' @param simplifyVector Logical. Passed on to `parse_json_body()`. It comes
#'   after `...`, so it matches only by its full name, and a condition field
#'   such as `simplify` cannot bind to it.
#' @return The parsed body.
#'
#' @noRd
parse_ok_body <- function(resp, label, ..., simplifyVector = FALSE) {
  tryCatch(
    parse_json_body(resp, simplifyVector = simplifyVector),
    error = function(cnd) {
      rlm_abort_bad_response(
        resp,
        label,
        "the response body did not parse as JSON.",
        hint = paste(
          "The server returned a response this package cannot read.",
          "Something other than LM Studio may be answering on this host."
        ),
        ...
      )
    }
  )
}

#' The hint text for a rejected call
#'
#' Kept apart from the abort so a test can read the two wordings without
#' raising, and so neither wording can pick up a token value by accident. The
#' flag is the only input, so nothing here can reach a token.
#'
#' @param token_sent Logical. Whether the request carried an API token.
#' @return One character string. The `FALSE` branch carries cli markup, so a
#'   caller that does not interpolate it through cli reads the braces as text.
#'   `rlm_abort_api()` hands it to `cli::cli_abort()`, which does interpolate.
#'
#' @noRd
api_error_hint <- function(token_sent) {
  if (isTRUE(token_sent)) {
    return("The server rejected the API token that was sent.")
  }
  paste(
    "Set the {.envvar RLMSTUDIO_API_TOKEN} environment variable",
    "or pass the {.arg token} argument to send an API token."
  )
}
