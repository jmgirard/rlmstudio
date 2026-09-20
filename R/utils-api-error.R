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
#' The length and `NA` guards are defensive. `httr2::resp_body_json()` parses
#' with `simplifyVector = FALSE`, so no response body reaches them: a JSON
#' array arrives as a list rather than as a longer vector. A test through the
#' wrappers cannot fire them while that holds.
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

  parsed <- tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)

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

#' The hint text for a rejected call
#'
#' Kept apart from the abort so a test can read the two wordings without
#' raising, and so neither wording can pick up a token value by accident.
#'
#' @param token_sent Logical. Whether the request carried an API token.
#' @return One character string.
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
