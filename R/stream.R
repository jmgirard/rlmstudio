#' Build arguments for log_stream
#' @noRd
build_args_log_stream <- function(source = c("model", "server"),
                                  filter = NULL,
                                  stats = FALSE,
                                  json = FALSE) {

  source <- match.arg(source)
  args <- c("log", "stream")

  if (source != "model") {
    args <- c(args, "--source", source)
  }

  if (!is.null(filter)) {
    filter_str <- paste(filter, collapse = ",")
    args <- c(args, "--filter", filter_str)
  }

  if (isTRUE(stats)) {
    args <- c(args, "--stats")
  }

  if (isTRUE(json)) {
    args <- c(args, "--json")
  }

  args
}

#' Stream logs from LM Studio
#'
#' Spawns a background process to stream logs from LM Studio. This is useful
#' for debugging prompts sent to the model or inspecting server operations.
#'
#' @param source Character. Source of logs: "model" or "server". Default is "model".
#' @param filter Character vector. Filter for model source. Can be "input",
#'   "output", or both (e.g., `c("input", "output")`).
#' @param stats Logical. Print prediction stats when available.
#' @param json Logical. Output logs as newline-separated JSON.
#'
#' @return A `processx::process` object representing the background stream.
#'   Use `read_log_stream()` to read output from this object.
#' @export
#'
#' @examples
#' \dontrun{
#' # Start streaming model IO as JSON
#' stream <- log_stream(source = "model", json = TRUE)
#'
#' # Later, stop the background process
#' stream$kill()
#' }
log_stream <- function(source = c("model", "server"),
                       filter = NULL,
                       stats = FALSE,
                       json = FALSE) {

  args <- build_args_log_stream(source = source,
                                filter = filter,
                                stats = stats,
                                json = json)

  # We use process$new here instead of processx::run because we need
  # this process to stay alive in the background
  p <- processx::process$new(
    command = "lms",
    args = args,
    stdout = "|",
    stderr = "|"
  )

  return(p)
}

#' Read streamed logs from LM Studio
#'
#' Reads the current unread output from a background log stream process created
#' by `log_stream()`. If the stream was started with `json = TRUE`, it attempts
#' to parse the newline-delimited JSON logs into a data frame.
#'
#' @param process A `processx::process` object created by `log_stream()`.
#'
#' @return A data frame if the logs were output as JSON and parsed successfully.
#'   Otherwise, returns a character vector of the raw log lines. Returns an empty
#'   data frame if no new logs are available.
#' @export
#'
#' @examples
#' \dontrun{
#' stream <- log_stream(source = "server", json = TRUE)
#'
#' # Wait for some logs to generate, then read them
#' Sys.sleep(2)
#' logs_df <- read_log_stream(stream)
#'
#' stream$kill()
#' }
read_log_stream <- function(process) {
  if (!inherits(process, "process")) {
    cli::cli_abort("The {.arg process} argument must be a {.cls processx} object created by {.fn log_stream}.")
  }

  lines <- process$read_output_lines()

  # Strip ANSI codes and carriage returns to ensure clean JSON parsing
  lines <- cli::ansi_strip(lines)
  lines <- gsub("\r", "", lines)
  lines <- lines[lines != ""]

  if (length(lines) == 0) {
    cli::cli_inform("No new logs available.")
    return(data.frame())
  }

  if (requireNamespace("jsonlite", quietly = TRUE)) {
    con <- textConnection(lines)
    on.exit(close(con))

    tryCatch({
      parsed_logs <- jsonlite::stream_in(con, verbose = FALSE)
      return(parsed_logs)
    }, error = function(e) {
      cli::cli_warn("Failed to parse JSON logs. Returning raw text.")
      return(lines)
    })
  } else {
    cli::cli_warn("The {.pkg jsonlite} package is required to parse JSON logs. Returning raw text.")
    return(lines)
  }
}
