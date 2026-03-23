#' Check if rlmstudio should be quiet
#'
#' Evaluates whether the user has set the global package option to silence
#' messages, or if a local quiet argument was passed.
#'
#' @param quiet Logical. A local override for the quiet setting.
#'
#' @return Logical.
#'
#' @noRd
#'
#' @examples
#' is_quiet(quiet = TRUE)
#' is_quiet(quiet = FALSE)
is_quiet <- function(quiet = NULL) {
  if (!is.null(quiet)) {
    return(isTRUE(quiet))
  }
  isTRUE(getOption("rlmstudio.quiet", default = FALSE))
}

#' @noRd
#' @examples
#' rlm_alert_info("This is an informational message.")
rlm_alert_info <- function(text, ..., .envir = parent.frame(), quiet = NULL) {
  if (!is_quiet(quiet)) {
    cli::cli_alert_info(text, ..., .envir = .envir)
  }
}

#' @noRd
#' @examples
#' rlm_alert_success("Task completed successfully!")
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
#' @examples
#' rlm_inform("Standard package information.")
rlm_inform <- function(text, ..., .envir = parent.frame(), quiet = NULL) {
  if (!is_quiet(quiet)) {
    cli::cli_inform(text, ..., .envir = .envir)
  }
}

#' @noRd
#' @examples
#' id <- rlm_progress_step("Initializing process...")
#' rlm_progress_done(id)
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
#' @examples
#' id <- rlm_progress_step("Downloading data...")
#' rlm_progress_update(id)
#' rlm_progress_done(id)
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
#' @examples
#' id <- rlm_progress_step("Finishing setup...")
#' rlm_progress_done(id)
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
