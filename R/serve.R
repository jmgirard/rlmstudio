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
#'
#' Opens a TCP connection to the hostname and port named in `host`. When
#' `host` names no port, the probe uses 1234, the LM Studio default. A `host`
#' with no scheme is read as `http://`. A `host` that does not parse is
#' reported as not running.
#'
#' @param host Character. The host address of the local server.
#' @return Logical.
#'
#' @noRd
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#'
#' if (is_server_running(host = "http://localhost:1234")) {
#'   message("The LM Studio server is currently active.")
#' }
#' }
is_server_running <- function(host = "http://localhost:1234") {
  if (!grepl("^[A-Za-z][A-Za-z0-9+.-]*://", host)) {
    host <- paste0("http://", host)
  }
  url <- tryCatch(httr2::url_parse(host), error = function(e) NULL)
  if (is.null(url)) {
    return(FALSE)
  }
  hostname <- url$hostname
  port <- if (is.null(url$port)) 1234L else as.integer(url$port)

  if (is.null(hostname) || identical(hostname, "")) {
    return(FALSE)
  }
  # url_parse keeps the brackets of an IPv6 literal; socketConnection does not
  # accept them.
  hostname <- sub("^\\[(.*)\\]$", "\\1", hostname)

  tryCatch(
    {
      con <- suppressWarnings(
        socketConnection(host = hostname, port = port, timeout = 0.5)
      )
      close(con)
      TRUE
    },
    error = function(e) FALSE
  )
}

#' Abort when the LM Studio server is not reachable
#'
#' Every REST wrapper calls this first. The condition carries the class
#' `rlmstudio_no_server` so callers can catch a stopped server by class.
#'
#' @param host Character. The host address of the local server.
#' @return Invisibly `TRUE` when the server answers. Aborts otherwise.
#'
#' @noRd
stop_if_no_server <- function(host = "http://localhost:1234") {
  if (!is_server_running(host)) {
    cli::cli_abort(
      "The LM Studio server is not running. Run {.fn lms_server_start} first.",
      class = "rlmstudio_no_server",
      call = NULL
    )
  }
  invisible(TRUE)
}

#' Check whether a host answers as a usable LM Studio server
#'
#' Sends one GET request to the model list endpoint at `host` and reports
#' whether the answer came from an LM Studio server that this package can use.
#' The answer is `TRUE` only when the request returns HTTP status 200 and the
#' response body carries a list of models. An empty list counts, because a
#' fresh LM Studio install has no models downloaded yet and its server still
#' works.
#'
#' Use this in place of a port check. Another process holding the port, a
#' server that has not finished starting, and a server that rejects the token
#' all answer the port and all report `FALSE` here.
#'
#' @param host Character. The base URL of the LM Studio server. Defaults to
#'   "http://localhost:1234".
#' @param timeout Numeric. The number of seconds to wait for the request
#'   before giving up. Defaults to 2. A host that opens the port and never
#'   answers reports `FALSE` after this many seconds.
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#'
#' @return `TRUE` or `FALSE`, always one value. This function raises no
#'   condition of its own for a network failure, a refused connection, an
#'   unparsable body, or a failed status. All of those report `FALSE`. A
#'   `token` that is not one character string and not `NULL` still aborts,
#'   because that is a fault in the call rather than a fact about the server.
#'
#' @seealso [lms_server_start()] to start the server. [lms_server_status()]
#'   for what the CLI reports about it.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#'
#' if (lms_server_ready()) {
#'   list_models()
#' }
#'
#' # A server on another port, with a shorter wait
#' lms_server_ready(host = "http://localhost:8080", timeout = 0.5)
#' }
lms_server_ready <- function(
  host = "http://localhost:1234",
  timeout = 2,
  token = NULL
) {
  req <- lms_client(host, token = token) |>
    httr2::req_url_path("api/v1/models") |>
    httr2::req_timeout(timeout) |>
    httr2::req_error(is_error = \(resp) FALSE)

  tryCatch(
    {
      resp <- httr2::req_perform(req)

      if (httr2::resp_status(resp) != 200L) {
        return(FALSE)
      }

      models <- httr2::resp_body_json(resp)[["models"]]

      # A JSON array parses to a list with no names. A JSON object parses to a
      # list with names, so a body that happens to hold a `models` object is
      # not a model list.
      is.list(models) && is.null(names(models))
    },
    error = function(e) FALSE
  )
}
