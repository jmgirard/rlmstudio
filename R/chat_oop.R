#' Create a new LM Studio chat result
#'
#' Internal constructor to create a structured object for responses containing
#' log probabilities.
#'
#' @param text Character. The generated text response.
#' @param logprobs Dataframe. The token-level probability data.
#'
#' @return An object of class \code{lms_chat_result}.
#'
#' @keywords internal
new_lms_chat_result <- function(text = character(), logprobs = data.frame()) {
  stopifnot(is.character(text))

  structure(
    list(
      text = text,
      logprobs = logprobs
    ),
    class = "lms_chat_result"
  )
}

#' Validate an LM Studio chat result
#'
#' Internal validator to ensure the integrity of \code{lms_chat_result} objects.
#'
#' @param x An object to validate.
#'
#' @return The validated object.
#'
#' @keywords internal
validate_lms_chat_result <- function(x) {
  if (!is.character(x$text)) {
    cli::cli_abort("{.arg text} must be a character vector.")
  }
  if (!is.null(x$logprobs) && !inherits(x$logprobs, "data.frame")) {
    cli::cli_abort("{.arg logprobs} must be a data.frame or NULL.")
  }
  x
}

#' Print an LM Studio chat result
#'
#' Custom print method for responses that include log probabilities. Displays
#' the text clearly and provides a summary of the metadata.
#'
#' @param x An object of class \code{lms_chat_result}.
#' @param ... Additional arguments passed to print.
#'
#' @return Invisibly returns the input object \code{x}.
#'
#' @keywords internal
#'
#' @export
print.lms_chat_result <- function(x, ...) {
  # Create a clean, themed layout using cli
  cli::cli_div(
    theme = list(rule = list(color = "cyan", "line-type" = "single"))
  )

  cli::cli_rule(left = "{.strong LM Studio Response}")

  # Print the generated text with padding
  cat("\n")
  cli::cli_text("{x$text}")
  cat("\n")

  cli::cli_rule()

  # Provide context about the logprobs if they exist
  if (
    !is.null(x$logprobs) &&
      inherits(x$logprobs, "data.frame") &&
      nrow(x$logprobs) > 0
  ) {
    # Count unique steps by looking at the step_token or step indices
    n_steps <- length(unique(x$logprobs$step_token))

    rlm_alert_info(
      "Includes log probabilities for {.val {n_steps}} token step{?s}. Access the data via {.code x$logprobs}"
    )
  } else {
    cli::cli_alert_warning("Log probability data is empty or missing.")
  }

  # Standard S3 practice: return the object invisibly
  invisible(x)
}
