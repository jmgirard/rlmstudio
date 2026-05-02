#' Build arguments for lms_server_start
#' @noRd
#'
#' @examples
#' build_args_server_start(port = 8080, cors = TRUE)
build_args_server_start <- function(port = NULL, cors = FALSE) {
  args <- c("server", "start")

  if (!is.null(port)) {
    args <- c(args, "--port", as.character(port))
  }

  if (isTRUE(cors)) {
    args <- c(args, "--cors")
  }

  args
}

#' Start the LM Studio local server
#'
#' Launches the LM Studio local server via the CLI, allowing you to interact
#' with loaded models via HTTP API calls.
#'
#' @param port Integer. Port to run the server on. If not provided, LM Studio
#'   uses the last used port.
#' @param cors Logical. Enable CORS support for web application development.
#'   Defaults to FALSE.
#'
#' @seealso [LM Studio CLI Server Start
#'   Documentation](https://lmstudio.ai/docs/cli/serve/server-start)
#'
#' @return Invisibly returns an integer representing the system exit code
#'   (\code{0} for success).
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Start server on the default port
#' lms_server_start()
#'
#' # Start server on a custom port with CORS enabled
#' lms_server_start(port = 8080, cors = TRUE)
#' }
lms_server_start <- function(port = NULL, cors = FALSE) {
  args <- build_args_server_start(port = port, cors = cors)

  res <- processx::run(lms_path(), args, error_on_status = FALSE)

  if (res$status == 0) {
    if (!is.null(port)) {
      rlm_alert_success(
        "LM Studio server started successfully on port {.val {port}}."
      )
    } else {
      rlm_alert_success(
        "LM Studio server started successfully on the default port."
      )
    }
  } else {
    cli::cli_abort(
      "Failed to start the LM Studio server. Exit code: {.val {res$status}}."
    )
  }

  invisible(res$status)
}

#' Build arguments for lms_server_stop
#' @noRd
#'
#' @examples
#' build_args_server_stop()
build_args_server_stop <- function() {
  c("server", "stop")
}

#' Stop the LM Studio local server
#'
#' Stops the currently running LM Studio local server via the CLI.
#'
#' @seealso [LM Studio CLI Server Stop
#'   Documentation](https://lmstudio.ai/docs/cli/serve/server-stop)
#'
#' @return Invisibly returns an integer representing the system exit code
#'   (\code{0} for success).
#'
#' @export
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#' lms_server_stop()
#' }
lms_server_stop <- function() {
  args <- build_args_server_stop()

  res <- processx::run(lms_path(), args, error_on_status = FALSE)

  if (res$status == 0) {
    rlm_alert_success("LM Studio server stopped successfully.")
  } else {
    cli::cli_abort(
      "Failed to stop the LM Studio server. Exit code: {.val {res$status}}."
    )
  }

  invisible(res$status)
}

#' Build arguments for lms_server_status
#' @noRd
#'
#' @examples
#' build_args_server_status(json = TRUE, quiet = TRUE)
build_args_server_status <- function(
  json = FALSE,
  verbose = FALSE,
  quiet = FALSE,
  log_level = NULL
) {
  args <- c("server", "status")

  if (isTRUE(json)) {
    args <- c(args, "--json")
  }
  if (isTRUE(verbose)) {
    args <- c(args, "--verbose")
  }
  if (isTRUE(quiet)) {
    args <- c(args, "--quiet")
  }
  if (!is.null(log_level)) {
    args <- c(args, "--log-level", as.character(log_level))
  }

  args
}

#' Check the status of the LM Studio server
#'
#' Displays the current status of the LM Studio local server via the CLI,
#' including whether it is running and its configuration.
#'
#' @param json Logical. Output the status in machine-readable JSON format.
#' @param verbose Logical. Enable detailed logging output.
#' @param quiet Logical. Suppress all logging output.
#' @param log_level Character. The level of logging to use (e.g., "info",
#'   "debug").
#'
#' @details You can only use one logging control flag at a time (`verbose`,
#'   `quiet`, or `log_level`).
#'
#' @seealso [LM Studio CLI Server Status
#'   Documentation](https://lmstudio.ai/docs/cli/serve/server-status)
#'
#' @return By default, returns a character vector containing the raw CLI output.
#'   If \code{json = TRUE} and the \code{jsonlite} package is available, it
#'   returns a parsed list or \code{data.frame} of the status configuration.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#'
#' # Get basic status string
#' lms_server_status()
#'
#' # Get status as a parsed JSON data frame
#' lms_server_status(json = TRUE)
#' }
lms_server_status <- function(
  json = FALSE,
  verbose = FALSE,
  quiet = FALSE,
  log_level = NULL
) {
  logging_flags <- sum(c(isTRUE(verbose), isTRUE(quiet), !is.null(log_level)))
  if (logging_flags > 1) {
    cli::cli_warn("Only one logging control flag can be used at a time.")
  }

  args <- build_args_server_status(
    json = json,
    verbose = verbose,
    quiet = quiet,
    log_level = log_level
  )

  res <- processx::run(lms_path(), args, error_on_status = FALSE)
  output <- paste(res$stdout, res$stderr, sep = "\n")

  lines <- strsplit(output, "\r?\n")[[1]]
  lines <- cli::ansi_strip(lines)
  lines <- gsub("\r", "", lines)
  lines <- lines[lines != ""]

  if (isTRUE(json) && requireNamespace("jsonlite", quietly = TRUE)) {
    tryCatch(
      {
        return(jsonlite::fromJSON(paste(lines, collapse = "\n")))
      },
      error = function(e) {
        cli::cli_warn(
          "Failed to parse JSON output. Returning raw character vector instead."
        )
        return(lines)
      }
    )
  }

  return(lines)
}

#' Check if the LM Studio server is reachable
#' @return Logical.
#'
#' @noRd
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#'
#' if (is_server_running()) {
#'   message("The LM Studio server is currently active.")
#' }
#' }
is_server_running <- function() {
  tryCatch(
    {
      con <- suppressWarnings(
        socketConnection(host = "localhost", port = 1234, timeout = 0.5)
      )
      close(con)
      TRUE
    },
    error = function(e) FALSE
  )
}
