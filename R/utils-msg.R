# utils-msg.R
# Internal wrappers for cli messages to respect the rlmstudio.quiet option

#' Check if rlmstudio should be quiet
#'
#' Evaluates whether the user has set the global package option to silence messages,
#' or if a local quiet argument was passed.
#'
#' @param quiet Logical. A local override for the quiet setting.
#' @return Logical.
#' @noRd
is_quiet <- function(quiet = NULL) {
  if (!is.null(quiet)) {
    return(isTRUE(quiet))
  }
  isTRUE(getOption("rlmstudio.quiet", default = FALSE))
}

#' @noRd
rlm_alert_info <- function(text, ..., .envir = parent.frame(), quiet = NULL) {
  if (!is_quiet(quiet)) {
    cli::cli_alert_info(text, ..., .envir = .envir)
  }
}

#' @noRd
rlm_alert_success <- function(
  text,
  ...,
  .envir = parent.frame(),
  quiet = NULL
) {
  if (!is_quiet(quiet)) {
    cli::cli_alert_success(text, ..., .envir = .envir)
  }
}

#' @noRd
rlm_inform <- function(text, ..., .envir = parent.frame(), quiet = NULL) {
  if (!is_quiet(quiet)) {
    cli::cli_inform(text, ..., .envir = .envir)
  }
}

#' @noRd
rlm_progress_step <- function(
  msg,
  msg_done = msg,
  ...,
  .envir = parent.frame(),
  quiet = NULL
) {
  if (!is_quiet(quiet)) {
    cli::cli_progress_step(msg = msg, msg_done = msg_done, ..., .envir = .envir)
  } else {
    invisible(NULL)
  }
}

#' @noRd
rlm_progress_update <- function(
  id = NULL,
  ...,
  .envir = parent.frame(),
  quiet = NULL
) {
  if (!is_quiet(quiet)) {
    cli::cli_progress_update(id = id, ..., .envir = .envir)
  }
}

#' @noRd
rlm_progress_done <- function(
  id = NULL,
  ...,
  .envir = parent.frame(),
  quiet = NULL
) {
  if (!is_quiet(quiet)) {
    cli::cli_progress_done(id = id, ..., .envir = .envir)
  }
}
