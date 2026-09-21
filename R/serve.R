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
#' The CLI returns before the REST API answers. By default this function then
#' keeps asking the REST API whether it is ready, for about `wait` seconds,
#' and returns once it answers. A script that calls the REST API on the next
#' line therefore no longer reports a missing server on a healthy machine.
#' The budget is a floor rather than a hard cap. No new request starts once
#' `wait` seconds have passed, so the call can overrun by at most the one
#' second a request already in flight is allowed.
#'
#' @param port Integer. Port to run the server on. If not provided, LM Studio
#'   uses the last used port.
#' @param cors Logical. Enable CORS support for web application development.
#'   Defaults to FALSE.
#' @param wait Numeric. How many seconds to keep asking the REST API whether
#'   it is ready. Defaults to 10. With `wait = 0` the function sends no
#'   readiness request and returns as soon as the CLI does. A `wait` that is
#'   not one number, zero or more, aborts before the CLI runs.
#' @param host Character or `NULL`. The base URL to ask. This says where to
#'   look for the server that was started. It does not change where the CLI
#'   starts it, which only `port` does. `NULL` picks a host as described
#'   below.
#'
#' @section Which host the wait asks:
#'
#' The host is picked in this order.
#'
#' * A `host` you give wins.
#' * With no `host` and a `port`, the host is `http://localhost:<port>`.
#' * With neither, the port that `lms_server_status(json = TRUE)` reports is
#'   read, and the host is `http://localhost:` plus that port.
#'
#' The request passes `token = NULL`, so it reads the `rlmstudio.token`
#' option and then the `RLMSTUDIO_API_TOKEN` environment variable. See
#' [rlmstudio_token].
#'
#' A wait that runs out does not abort. The server was already started and
#' that cannot be undone, so the function raises a warning and returns the
#' CLI exit code. A call with no `host` and no `port` whose port read yields
#' nothing raises its own warning and sends no readiness request. Neither
#' warning is silenced by the `rlmstudio.quiet` option.
#'
#' @seealso [LM Studio CLI Server Start
#'   Documentation](https://lmstudio.ai/docs/cli/serve/server-start).
#'   [lms_server_ready()] for the readiness check this function calls.
#'
#' @return Invisibly returns an integer representing the system exit code
#'   (\code{0} for success).
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Start server on the default port and wait for the REST API
#' lms_server_start()
#'
#' # Start server on a custom port with CORS enabled
#' lms_server_start(port = 8080, cors = TRUE)
#'
#' # Return as soon as the CLI does, without waiting
#' lms_server_start(wait = 0)
#'
#' # Wait longer, and ask a host the rules above would not pick
#' lms_server_start(wait = 60, host = "http://127.0.0.1:1234")
#' }
lms_server_start <- function(
  port = NULL,
  cors = FALSE,
  wait = 10,
  host = NULL
) {
  rlm_check_wait(wait)

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

  if (wait > 0) {
    warn_unless_ready(host = host, port = port, wait = wait)
  }

  invisible(res$status)
}

#' Pick the host that the wait asks
#'
#' @param host Character or `NULL`. What the caller gave.
#' @param port What the caller gave.
#'
#' @return One base URL, or `NULL` when no port could be found.
#'
#' @noRd
wait_host <- function(host = NULL, port = NULL) {
  if (!is.null(host)) {
    return(host)
  }
  if (is.null(port)) {
    port <- server_status_port()
  }
  if (is.null(port)) {
    return(NULL)
  }
  paste0("http://localhost:", port)
}

#' Wait for the server, and warn rather than abort when it does not answer
#'
#' The warnings go through `cli::cli_warn()` and not through the helpers in
#' `R/utils-msg.R`, so the `rlmstudio.quiet` option does not silence them.
#' GP6 is traded against GP3 here. Aborting cannot undo a start that already
#' ran, and a wait that ran out is a fault rather than progress chatter.
#'
#' @param host Character or `NULL`. What the caller gave.
#' @param port What the caller gave.
#' @param wait Numeric. The budget in seconds.
#'
#' @return `TRUE` when the server answered, `FALSE` otherwise, invisibly.
#'
#' @noRd
warn_unless_ready <- function(host = NULL, port = NULL, wait = 10) {
  target <- wait_host(host = host, port = port)

  if (is.null(target)) {
    cli::cli_warn(c(
      "Could not tell which host to ask whether the server is ready.",
      "x" = "The CLI status output reported no port this package can use.",
      "i" = "Give {.arg host} or {.arg port} to say where the server is."
    ))
    return(invisible(FALSE))
  }

  if (wait_for_server(target, wait = wait)) {
    return(invisible(TRUE))
  }

  cli::cli_warn(c(
    "The LM Studio server at {.url {target}} did not answer in time.",
    "i" = "It was asked for {wait} second{?s}. Raise {.arg wait} to allow
           longer."
  ))
  invisible(FALSE)
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

#' Read the port that the CLI reports for the local server
#'
#' `lms server status --json` prints one JSON object with two fields, `port`
#' and `running`. `lms_server_status(json = TRUE)` parses it, so the port sits
#' at the top level of the returned list. The `running` field is not read.
#' The caller has already seen the CLI report a successful start, and that
#' field can still read `FALSE` in the moment right after a start, which is
#' the race this helper serves.
#'
#' The CLI reports the last used port even while the server is stopped, so a
#' port comes back in both states.
#'
#' @return One integer port, or `NULL` when the status output carries no
#'   usable port. `lms_server_status()` returns a character vector rather
#'   than a list when jsonlite is missing or the output does not parse, and
#'   that shape yields `NULL` too.
#'
#' @noRd
server_status_port <- function() {
  status <- tryCatch(
    lms_server_status(json = TRUE),
    error = function(e) NULL
  )

  if (!is.list(status)) {
    return(NULL)
  }

  port <- status[["port"]]
  # A logical is excluded on purpose. `as.integer(TRUE)` is 1, so a `port`
  # field holding TRUE would otherwise read as port 1.
  if (!is.numeric(port) && !is.character(port)) {
    return(NULL)
  }
  if (length(port) != 1L) {
    return(NULL)
  }

  port <- suppressWarnings(as.numeric(port))
  if (is.na(port) || port != trunc(port) || port < 1 || port > 65535) {
    return(NULL)
  }

  as.integer(port)
}

#' Ask the server whether it is ready, again and again, until a budget runs out
#'
#' Sends one readiness request, and on a `FALSE` sleeps and sends another. It
#' stops at the first `TRUE`. Once `wait` seconds have passed it starts no
#' further request, so the call can run past the budget only by the time a
#' request already in flight needs, which `timeout` bounds.
#'
#' The request passes `token = NULL`. `lms_server_ready()` reads `NULL` as
#' the `rlmstudio.token` option and then the `RLMSTUDIO_API_TOKEN`
#' environment variable, which is what a caller of `lms_server_start()` gets.
#'
#' @param host Character. The base URL to probe.
#' @param wait Numeric. The number of seconds to keep asking for. A `wait` of
#'   zero sends no request at all.
#' @param timeout Numeric. How long one request waits for an answer.
#' @param pause Numeric. How long to sleep between two requests.
#'
#' @return `TRUE` when a request reported the server ready inside the budget,
#'   `FALSE` otherwise.
#'
#' @noRd
wait_for_server <- function(host, wait, timeout = 1, pause = 0.25) {
  if (wait <= 0) {
    return(FALSE)
  }

  deadline <- Sys.time() + wait

  repeat {
    if (Sys.time() >= deadline) {
      return(FALSE)
    }

    ready <- lms_server_ready(host = host, timeout = timeout, token = NULL)
    if (isTRUE(ready)) {
      return(TRUE)
    }

    remaining <- as.numeric(difftime(deadline, Sys.time(), units = "secs"))
    if (remaining <= 0) {
      return(FALSE)
    }
    Sys.sleep(min(pause, remaining))
  }
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
#' @section Call faults that abort:
#'
#' A fault in the call is not a fact about the server, so it aborts rather
#' than reporting `FALSE`. These messages come from the packages underneath.
#' The httr2 ones name httr2's own arguments, `url` for `host` and `seconds`
#' for `timeout`. The curl one names no argument at all. Six such faults are
#' named below.
#'
#' * A `host` of `NULL`. httr2 reports that `url` must be a single string,
#'   not `NULL`.
#' * A `host` of more than one string. httr2 reports that `url` must be a
#'   single string, not a character vector.
#' * A `host` that is a character `NA`. httr2 reports that `url` must be a
#'   single string, not a character `NA`.
#' * A `host` that is one string but cannot be parsed as a URL. curl reports
#'   that it failed to parse the URL and names the reason. A `host` holding a
#'   space gives "Malformed input to a URL function". An empty `host` gives
#'   "No host part in the URL".
#' * A `timeout` below one millisecond. httr2 reports that `seconds` must be
#'   greater than 1 ms.
#' * A `timeout` that is not one number, such as a string or a vector of two.
#'   httr2 reports that `seconds` must be a number, and names either the
#'   value or its type.
#'
#' Those six are not the whole list. Any `host` that is not one string aborts
#' the same way, whatever the reason, and httr2 names either the value or its
#' type. A `host` of `1` gives "not the number 1". A `host` of `list("a")`
#' gives "not a list". A `host` of `character(0)` gives "not an empty
#' character vector".
#'
#' The `token` fault named above aborts the same way. It comes from this
#' package rather than from httr2.
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

      is_model_list(httr2::resp_body_json(resp)[["models"]])
    },
    error = function(e) FALSE
  )
}

#' Is this parsed value a list of models?
#'
#' @param models The value parsed out of the `models` key of a response body.
#'
#' @return Logical.
#'
#' @noRd
is_model_list <- function(models) {
  # A JSON array parses to a list with no names. A JSON object parses to a
  # list with names, so a body that happens to hold a `models` object is not a
  # model list.
  if (!is.list(models) || !is.null(names(models))) {
    return(FALSE)
  }

  # Every entry of a real model list is a JSON object, which parses to a named
  # list. An array of bare strings or numbers is some other server's answer.
  all(vapply(
    models,
    function(entry) is.list(entry) && !is.null(names(entry)),
    logical(1)
  ))
}
