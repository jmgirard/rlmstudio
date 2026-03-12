#' Build arguments for server_start
#' @noRd
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
#' Launches the LM Studio local server, allowing you to interact with loaded
#' models via HTTP API calls.
#'
#' @param port Integer. Port to run the server on. If not provided, LM Studio
#'   uses the last used port.
#' @param cors Logical. Enable CORS support for web application development.
#'   Defaults to FALSE.
#'
#' @return Invisibly returns the system exit code (0 for success).
#' @export
#'
#' @examples
#' \dontrun{
#' # Start on default port
#' server_start()
#'
#' # Start on port 3000 with CORS enabled
#' server_start(port = 3000, cors = TRUE)
#' }
server_start <- function(port = NULL, cors = FALSE) {
  args <- build_args_server_start(port = port, cors = cors)

  # Let processx run silently in the background by capturing output
  # but we won't print it unless there is an error
  res <- processx::run("lms", args, error_on_status = FALSE)

  if (res$status == 0) {
    cli::cli_alert_success("LM Studio server started successfully.")
  } else {
    cli::cli_abort("Failed to start the LM Studio server. Exit code: {.val {res$status}}.")
  }

  invisible(res$status)
}

#' Build arguments for server_stop
#' @noRd
build_args_server_stop <- function() {
  c("server", "stop")
}

#' Stop the LM Studio local server
#'
#' Stops the currently running LM Studio local server.
#'
#' @return Invisibly returns the system exit code (0 for success).
#' @export
#'
#' @examples
#' \dontrun{
#' server_stop()
#' }
server_stop <- function() {
  args <- build_args_server_stop()

  res <- processx::run("lms", args, error_on_status = FALSE)

  if (res$status == 0) {
    cli::cli_alert_success("LM Studio server stopped successfully.")
  } else {
    cli::cli_abort("Failed to stop the LM Studio server. Exit code: {.val {res$status}}.")
  }

  invisible(res$status)
}

#' Build arguments for server_status
#' @noRd
build_args_server_status <- function(json = FALSE, verbose = FALSE, quiet = FALSE, log_level = NULL) {
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
#' Displays the current status of the LM Studio local server, including whether
#' it is running and its configuration.
#'
#' @param json Logical. Output the status in machine-readable JSON format.
#' @param verbose Logical. Enable detailed logging output.
#' @param quiet Logical. Suppress all logging output.
#' @param log_level Character. The level of logging to use (e.g., "info", "debug").
#'
#' @details You can only use one logging control flag at a time (`verbose`,
#'   `quiet`, or `log_level`).
#'
#' @return A character vector of the raw CLI output. If `json = TRUE` and the
#'   `jsonlite` package is installed, it returns a parsed list or data frame.
#' @export
#'
#' @examples
#' \dontrun{
#' # Standard status
#' server_status()
#'
#' # Quiet JSON output parsed directly into R
#' status_data <- server_status(json = TRUE, quiet = TRUE)
#' }
server_status <- function(json = FALSE, verbose = FALSE, quiet = FALSE, log_level = NULL) {

  logging_flags <- sum(c(isTRUE(verbose), isTRUE(quiet), !is.null(log_level)))
  if (logging_flags > 1) {
    cli::cli_warn("Only one logging control flag can be used at a time.")
  }

  args <- build_args_server_status(json = json, verbose = verbose, quiet = quiet, log_level = log_level)

  # Capture both streams to ensure no status messages are missed
  res <- processx::run("lms", args, error_on_status = FALSE)
  output <- paste(res$stdout, res$stderr, sep = "\n")

  lines <- strsplit(output, "\r?\n")[[1]]
  lines <- cli::ansi_strip(lines)

  # Remove \r without losing the content of the line
  lines <- gsub("\r", "", lines)
  lines <- lines[lines != ""]

  if (isTRUE(json) && requireNamespace("jsonlite", quietly = TRUE)) {
    tryCatch({
      return(jsonlite::fromJSON(paste(lines, collapse = "\n")))
    }, error = function(e) {
      cli::cli_warn("Failed to parse JSON output. Returning raw character vector instead.")
      return(lines)
    })
  }

  return(lines)
}
