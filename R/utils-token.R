#' Resolve the API token for one request
#'
#' Reads three sources in a fixed order and returns the first one that holds
#' something: the explicit argument, the `rlmstudio.token` option, then the
#' `RLMSTUDIO_API_TOKEN` environment variable. A source that is `NULL` or an
#' empty string counts as unset, so an unset environment variable, which
#' `Sys.getenv()` reports as `""`, falls through like a missing one.
#'
#' An argument of any other shape aborts. Falling through on it would discard
#' a token the caller meant to send and reach for a different source, or send
#' none and then tell the caller to pass the argument they just passed. The
#' option and the variable keep falling through, because neither one is a
#' value the caller handed to this call.
#'
#' @param token Character or `NULL`. The token the caller passed.
#' @return One character string, or `NULL` when no source holds a token.
#'
#' @noRd
rlm_token <- function(token = NULL) {
  if (!is.null(token) &&
    !(is.character(token) && length(token) == 1L && !is.na(token))) {
    cli::cli_abort(
      "{.arg token} must be one character string or {.code NULL}.",
      call = NULL
    )
  }

  if (is.character(token) && length(token) == 1L && !is.na(token) &&
    nzchar(token)) {
    return(token)
  }

  opt <- getOption("rlmstudio.token")
  if (is.character(opt) && length(opt) == 1L && !is.na(opt) && nzchar(opt)) {
    return(opt)
  }

  env <- Sys.getenv("RLMSTUDIO_API_TOKEN")
  if (nzchar(env)) {
    return(env)
  }

  NULL
}
