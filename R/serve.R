#' Build arguments for lms_server_start
#' @noRd
#'
#' @examples
#' build_args_server_start(port = 8080, cors = TRUE)
build_args_server_start <- function(port = NULL, cors = FALSE) {
  args <- c("server", "start")

  if (!is.null(port)) {
    # lms_server_start() passes an integer already. The integer step covers a
    # direct call with a double, which as.character() can print in
    # scientific notation, such as "8.08e+03" under options(scipen = -5).
    args <- c(args, "--port", as.character(as.integer(port)))
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
#' The budget is not a hard cap. No new request starts once `wait` seconds
#' have passed, but a request already in flight is allowed one second to
#' finish. With no `host` and no `port`, the function first asks the CLI
#' which port the server uses, and that read runs before the `wait` seconds
#' start to count.
#'
#' @param port Numeric or `NULL`. Port to run the server on. It must be one
#'   whole number from 1 to 65535, given as a number and not as an array or a
#'   string. `NULL`, the default, lets LM Studio use the last used port.
#' @param cors Logical. Enable CORS support for web application development.
#'   Must be `TRUE` or `FALSE`. Defaults to `FALSE`. Any other value, `NULL`
#'   and `NA` included, aborts before the `lms` CLI runs.
#' @param wait Numeric. How many seconds to keep asking the REST API whether
#'   it is ready. Defaults to 10. With `wait = 0` the function sends no
#'   readiness request and returns as soon as the CLI does. A `wait` that is
#'   not one number, zero or more, aborts before the CLI runs.
#' @param host Character or `NULL`. The base URL to ask. This says where to
#'   look for the server that was started. It does not change where the CLI
#'   starts it, which only `port` does. `NULL` picks a host as described
#'   below.
#' @param token Character or `NULL`. An API token for the readiness request,
#'   for a server that requires authentication. `NULL` reads the
#'   `rlmstudio.token` option and then the `RLMSTUDIO_API_TOKEN` environment
#'   variable. See [rlmstudio_token].
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
#' The request carries `token`, read as described under that argument.
#'
#' Five faults in the call abort before the CLI runs, with any `wait`: a bad
#' `wait`, `port`, `cors`, `host`, or `token`. A bad `host` is one that is
#' not `NULL` and that the readiness request cannot be built from, such as a
#' vector of two strings, `NA`, an empty string, or `"localhost:1234"`, which
#' lacks `http://`. That message names `host` and quotes the reason httr2 or
#' curl gave. A bad `token` is one that is not one character string and not
#' `NULL`.
#'
#' If the CLI refuses the start and exits with a status other than 0, the
#' function aborts. The message gives the exit code and quotes what the CLI
#' wrote, after "The CLI said:". The quoted text is the stderr text, or the
#' stdout text if stderr holds only whitespace and escape codes. A byte that
#' is not valid UTF-8 shows as `<xx>`, its hex value. ANSI escape codes,
#' such as color codes, cursor codes, and terminal links, are removed, and
#' each run of whitespace becomes one space. A text longer than 1000
#' characters keeps at most its last 1000 characters, after "…".
#'
#' A wait that runs out does not abort. The server was already started and
#' that cannot be undone, so the function raises a warning and returns the
#' CLI exit code. A call with no `host` and no `port` whose port read yields
#' nothing raises its own warning and sends no readiness request. If the
#' readiness check itself aborts during the wait, the function raises a
#' third warning. It names the host, quotes the abort message, and the
#' function returns the CLI exit code. None of the three warnings is
#' silenced by the `rlmstudio.quiet` option.
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
  host = NULL,
  token = NULL
) {
  rlm_check_wait(wait)
  rlm_check_port(port)
  rlm_check_flag(cors, "cors")
  # The port goes to the CLI, the success message, and the readiness host. An
  # integer prints as plain digits under any scipen option, and as.integer()
  # also drops names.
  if (!is.null(port)) {
    port <- as.integer(port)
  }
  # Faults in host and token are knowable without a server, and a start that
  # has already run cannot be undone, so both are checked before the CLI runs.
  # The host check builds its request with token = NULL, so it never sees the
  # caller's token. That token is checked here on its own.
  rlm_token(token)
  if (!is.null(host)) {
    rlm_check_ready_host(host)
  }

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
    rlm_abort_cli_run("Failed to start the LM Studio server.", res)
  }

  if (wait > 0) {
    warn_unless_ready(host = host, port = port, wait = wait, token = token)
  }

  invisible(res$status)
}

#' Abort for a failed CLI run
#'
#' The message gives the exit code. If the run wrote any text, a bullet
#' quotes it after `label`. The quoted text is `text`, cut by
#' `cli_output_cut()`. A caller that looks for a phrase reads
#' `cli_output_clean()` first and passes it as `text`, so a phrase far from
#' the end is still found.
#'
#' @param what The first sentence of the message. It is a cli format string,
#'   so it never holds text from the CLI.
#' @param res The list `processx::run()` returned.
#' @param text The text of `cli_output_clean(res)`, for a caller that has
#'   already read it.
#' @param label The words before the quoted text.
#' @param hint Further bullets, as cli format strings.
#' @param call The call the error names.
#'
#' @noRd
rlm_abort_cli_run <- function(
  what,
  res,
  text = cli_output_clean(res),
  label = "The CLI said",
  hint = NULL,
  call = parent.frame()
) {
  status <- res$status
  output <- cli_output_cut(text)
  msg <- paste(what, "Exit code: {.val {status}}.")
  # The CLI text is spliced in as a value, so cli does not run its braces
  # (LESSONS, M012).
  if (!is.null(output)) {
    msg <- c(msg, "x" = paste0(label, ": {output}"))
  }
  cli::cli_abort(c(msg, hint), call = call)
}

#' Clean the text a failed CLI run gave
#'
#' The CLI writes its reason to stderr, so stderr is read first and stdout
#' only when stderr holds nothing. A field that is absent, `NULL`, `NA`, or
#' only whitespace and escape codes holds nothing. A byte that is not valid UTF-8 is written
#' as `<xx>`, its hex value. ANSI escape codes are removed by
#' `cli::ansi_strip()` and then `strip_escapes()`. Each whitespace run becomes one space, so a text of
#' several lines fits on one bullet.
#'
#' @param res The list `processx::run()` returned.
#' @return One string, or `NULL` when neither field holds text.
#'
#' @noRd
cli_output_clean <- function(res) {
  for (field in c("stderr", "stdout")) {
    text <- res[[field]]
    if (is.character(text) && length(text) == 1L && !is.na(text)) {
      # A byte that is not valid UTF-8 makes gsub() fail, which would hide
      # the exit code. sub = "byte" writes such a byte as "<ff>".
      text <- iconv(text, "UTF-8", "UTF-8", sub = "byte")
      # Color codes, other cursor codes, and terminal links. The call names
      # no arguments, so it does not depend on which ones a cli version has.
      text <- cli::ansi_strip(text)
      text <- strip_escapes(text)
      # Collapse first. trimws() alone keeps a form feed or a vertical tab,
      # and [:space:] does not match a non-breaking space (LESSONS, M013).
      text <- trimws(gsub("[[:space:]\u00a0]+", " ", text))
      if (nzchar(text)) {
        return(text)
      }
    }
  }
  NULL
}

#' Remove the escape sequences that cli::ansi_strip() leaves
#'
#' Removes, in this order: a string sequence (ESC followed by `]`, `P`,
#' `X`, `^`, or `_`) up to BEL or ESC \, such as a window title, or up to
#' the next ESC or the end of the text when it has no terminator; a
#' two-character code with any intermediate bytes, such as the cursor save
#' and restore codes ESC 7 and ESC 8 or the character set code ESC ( B; and
#' a lone ESC.
#'
#' @param text One string.
#' @return One string.
#'
#' @noRd
strip_escapes <- function(text) {
  text <- gsub("\033[]PX^_][^\a\033]*(\a|\033\\\\)?", "", text, perl = TRUE)
  text <- gsub("\033[ -/]*[0-~]", "", text, perl = TRUE)
  gsub("\033", "", text, fixed = TRUE)
}

#' Cut a long CLI text to its end
#'
#' A text of more than `max` characters keeps its last `max`, after a
#' leading "\u2026" that is not counted. The end of a log usually holds the
#' reason for a failure. If the cut splits any `<xx>` text (`<`, two
#' lowercase hex digits, `>`), such as a token of `cli_output_clean()`, the
#' part is dropped. The CLI's own text of that shape is dropped the same way.
#'
#' @param text One string, or `NULL`.
#' @param max The number of characters to keep.
#' @return One string, or `NULL` when `text` is `NULL`.
#'
#' @noRd
cli_output_cut <- function(text, max = 1000L) {
  if (is.null(text) || nchar(text) <= max) {
    return(text)
  }
  first <- nchar(text) - max + 1L
  kept <- substr(text, first, nchar(text))
  # A token that starts at one of the three characters before the cut and
  # ends at or after it is split. Its end is dropped from what is kept.
  for (start in (first - 3L):(first - 1L)) {
    if (
      start >= 1L && grepl("^<[0-9a-f]{2}>$", substr(text, start, start + 3L))
    ) {
      kept <- substr(kept, start + 4L - first + 1L, nchar(kept))
      break
    }
  }
  paste0("\u2026", kept)
}

#' Reject a host the readiness request cannot be built from
#'
#' Builds the request `lms_server_ready()` would send, and sends nothing. The
#' build reads the token sources, but with `token = NULL` it reads only the
#' option and the environment variable, and neither of those aborts. Any
#' abort here therefore comes from `host`. The message names `host` and
#' quotes the reason httr2 or curl gave. An httr2 reason names httr2's own
#' `url`, and a curl reason names no argument.
#'
#' @param host The value the caller passed. Not `NULL`.
#' @return `host`, invisibly.
#'
#' @noRd
rlm_check_ready_host <- function(host) {
  tryCatch(
    server_ready_request(host, timeout = 1, token = NULL),
    error = function(e) {
      reason <- conditionMessage(e)
      cli::cli_abort(
        c(
          "{.arg host} must be a URL the readiness request can be built from.",
          "x" = "{reason}"
        ),
        call = NULL
      )
    }
  )
  invisible(host)
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
#' @param token Character or `NULL`. Passed to `lms_server_ready()`.
#'
#' @return `TRUE` when the server answered, `FALSE` otherwise, invisibly.
#'
#' @noRd
warn_unless_ready <- function(host = NULL, port = NULL, wait = 10,
                              token = NULL) {
  target <- wait_host(host = host, port = port)

  if (is.null(target)) {
    cli::cli_warn(c(
      "Could not tell which host to ask whether the server is ready.",
      "x" = "The CLI status output reported no port this package can use.",
      "i" = "Give {.arg host} or {.arg port} to say where the server is."
    ))
    return(invisible(FALSE))
  }

  # Each input the target is built from is checked before this point. The
  # caller's host and port are checked before the CLI runs, and the port is
  # an integer by then. server_status_port() drops a port it cannot use. The tryCatch() stays as
  # a guard. The start already ran and cannot be undone, so an abort from the
  # probe becomes one warning.
  # suppressWarnings() sits inside the tryCatch() so that a warning the probe
  # raises before it aborts does not reach the user as a second warning for
  # the same fault.
  ready <- tryCatch(
    suppressWarnings(wait_for_server(target, wait = wait, token = token)),
    error = function(e) e
  )

  if (inherits(ready, "error")) {
    reason <- conditionMessage(ready)
    cli::cli_warn(c(
      "Could not ask the LM Studio server at {.url {target}} whether it is
       ready.",
      "x" = "{reason}",
      "i" = "The server was started. Call {.fn lms_server_ready} to ask
             again."
    ))
    return(invisible(FALSE))
  }

  if (ready) {
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
#' If the CLI exits with a status other than 0, the function reads what the
#' CLI wrote. If the text says "not running", the function prints an info
#' message and returns the exit code invisibly, with no abort. Letter case
#' does not matter. With no server running, the CLI exits with status 1 and
#' says so. [lms_daemon_stop()] with `force = TRUE` shows the same message.
#'
#' Any other failure aborts. The message gives the exit code and quotes what
#' the CLI wrote, after "The CLI said:". The quoted text is the stderr text,
#' or the stdout text if stderr holds only whitespace and escape codes. A
#' byte that is not valid UTF-8 shows as `<xx>`, its hex value. ANSI escape
#' codes, such as color codes, cursor codes, and terminal links, are
#' removed, and each run of whitespace becomes one space. A text longer than
#' 1000 characters keeps at most its last 1000 characters, after "…".
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
    return(invisible(res$status))
  }

  # With no server running, the CLI exits 1 and writes "Error: The server is
  # not running." to stderr (lms, 2026-09-29). A second stop is then a
  # no-op. The phrase is read before the cut, so a long text still matches.
  text <- cli_output_clean(res)
  if (!is.null(text) && grepl("not running", text, ignore.case = TRUE)) {
    rlm_alert_info("The LM Studio server is already stopped.")
    return(invisible(res$status))
  }

  rlm_abort_cli_run("Failed to stop the LM Studio server.", res, text = text)
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
#' @param json `TRUE` or `FALSE`. Output the status in machine-readable JSON
#'   format. Any other value, `NULL` and `NA` included, aborts before the `lms`
#'   CLI runs.
#' @param verbose `TRUE` or `FALSE`. Enable detailed logging output. Any other
#'   value, `NULL` and `NA` included, aborts before the `lms` CLI runs.
#' @param quiet `TRUE` or `FALSE`. `TRUE` passes `--quiet` to the `lms` CLI,
#'   which suppresses all logging output. The `rlmstudio.quiet` option does not
#'   change it. Any other value, `NULL` and `NA` included, aborts before the
#'   `lms` CLI runs.
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
  rlm_check_flag(json, "json")
  rlm_check_flag(verbose, "verbose")
  rlm_check_flag(quiet, "quiet")

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
#'   that shape yields `NULL` too. The warning that `lms_server_status()`
#'   raises for output that does not parse is muffled.
#'
#' @noRd
server_status_port <- function() {
  # The parse warning is muffled because the caller warns about a missing
  # port itself, and two warnings about one fault read as two faults.
  status <- tryCatch(
    suppressWarnings(lms_server_status(json = TRUE)),
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
#' The request passes `token` on. `lms_server_ready()` reads `NULL` as the
#' `rlmstudio.token` option and then the `RLMSTUDIO_API_TOKEN` environment
#' variable.
#'
#' @param host Character. The base URL to probe.
#' @param wait Numeric. The number of seconds to keep asking for. A `wait` of
#'   zero sends no request at all.
#' @param timeout Numeric. How long one request waits for an answer.
#' @param pause Numeric. How long to sleep between two requests.
#' @param token Character or `NULL`. Passed to `lms_server_ready()`.
#'
#' @return `TRUE` when a request reported the server ready inside the budget,
#'   `FALSE` otherwise.
#'
#' @noRd
wait_for_server <- function(host, wait, timeout = 1, pause = 0.25,
                            token = NULL) {
  if (wait <= 0) {
    return(FALSE)
  }

  deadline <- Sys.time() + wait

  repeat {
    if (Sys.time() >= deadline) {
      return(FALSE)
    }

    ready <- lms_server_ready(host = host, timeout = timeout, token = token)
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
#' response body is a model list that [list_models()] can read. The two
#' functions apply the same shape rules, which the "Malformed model list"
#' section of [list_models()] states. An empty list counts, because a
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
  req <- server_ready_request(host, timeout = timeout, token = token)

  tryCatch(
    {
      resp <- httr2::req_perform(req)

      if (httr2::resp_status(resp) != 200L) {
        return(FALSE)
      }

      is.null(model_list_fault(parse_json_body(resp)))
    },
    error = function(e) FALSE
  )
}

#' Build the readiness request without sending it
#'
#' `lms_server_ready()` sends the request this builds. When the caller gave a
#' `host`, `lms_server_start()` builds it once before the CLI runs, so such a
#' `host` the build rejects aborts before a server starts. Any fault in
#' `host`, `timeout`, or `token` aborts here, with the message of the
#' package that raised it.
#'
#' @param host Character. The base URL of the LM Studio server.
#' @param timeout Numeric. The number of seconds the request may wait.
#' @param token Character or `NULL`. Passed to `lms_client()`.
#'
#' @return An httr2 request object.
#'
#' @noRd
server_ready_request <- function(host, timeout = 2, token = NULL) {
  lms_client(host, token = token) |>
    httr2::req_url_path("api/v1/models") |>
    httr2::req_timeout(timeout) |>
    httr2::req_error(is_error = \(resp) FALSE)
}
