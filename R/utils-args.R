#' Reject a model or job name that is not one usable string
#'
#' The wrappers name `model` and `job_id` as arguments, so GP4 puts the input
#' check on the package rather than on the server. The check runs before the
#' server probe, because a fault in the argument is knowable without a server.
#'
#' @param value The value the caller passed.
#' @param arg Character. The argument name to report.
#' @return `value`, invisibly.
#'
#' @noRd
rlm_check_id <- function(value, arg) {
  fault <- id_fault(value)
  if (!is.null(fault)) {
    cli::cli_abort(
      c("{.arg {arg}} must be one name, given as a single string.", "x" = fault),
      call = NULL
    )
  }
  invisible(value)
}

#' Which rule did this model or job name break?
#'
#' Returns plain text rather than a cli string. cli interpolates the braces of
#' the string it is handed (LESSONS, M012), and a name the caller chose can
#' carry braces of its own, so the detail names no value back to the user.
#'
#' @param value The value the caller passed.
#' @return A one-sentence detail, or `NULL` when the value is usable.
#'
#' @noRd
id_fault <- function(value) {
  if (is.null(value)) {
    return("You gave NULL.")
  }
  if (!is.character(value)) {
    return(paste0("You gave a ", class(value)[[1]], " value."))
  }
  if (length(value) != 1L) {
    return(paste0("You gave ", length(value), " values rather than one."))
  }
  if (is.na(value)) {
    return("You gave NA.")
  }
  if (!nzchar(value)) {
    return("You gave an empty string.")
  }
  if (!nzchar(trimws(value))) {
    return("You gave a string of whitespace only.")
  }
  NULL
}

#' Reject a text argument that is not a usable character vector
#'
#' The strict rule, for the arguments that are genuinely vectors of text:
#' `lms_embed(input)` and `lms_chat_batch(inputs)`.
#'
#' @param value The value the caller passed.
#' @param arg Character. The argument name to report.
#' @return `value`, invisibly.
#'
#' @noRd
rlm_check_text <- function(value, arg) {
  if (!is.character(value) || length(value) == 0) {
    cli::cli_abort(
      "{.arg {arg}} must be a non-empty character vector.",
      call = NULL
    )
  }
  rlm_check_no_na(value, arg)
}

#' Reject a missing value inside a text argument
#'
#' The loose rule, for the chat wrappers. Their `input` is a named formal, so
#' the dots escape hatch cannot reach it and a type check there would take the
#' structured OpenResponses input form away for good. This checks the character
#' case alone and lets every other shape through to the server.
#'
#' An `NA` reaches the server as JSON `null`, which no server error names back.
#'
#' @param value The value the caller passed.
#' @param arg Character. The argument name to report.
#' @return `value`, invisibly.
#'
#' @noRd
rlm_check_no_na <- function(value, arg) {
  if (is.character(value) && anyNA(value)) {
    count <- sum(is.na(value))
    cli::cli_abort(
      c(
        "{.arg {arg}} must hold no missing values.",
        "x" = paste0(
          "You gave ",
          count,
          if (count == 1L) " NA value." else " NA values."
        )
      ),
      call = NULL
    )
  }
  invisible(value)
}
