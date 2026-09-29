#' Build arguments for lms_daemon_start
#' @noRd
#'
#' @examples
#' build_args_daemon_up()
build_args_daemon_up <- function() {
  c("daemon", "up")
}

#' Start the LM Studio headless daemon
#'
#' Launches the `llmster` daemon in the background via the CLI. This is required
#' in headless environments (such as Linux servers) before loading models or
#' starting the local server.
#'
#' If the CLI exits with a status other than 0, the function aborts. The
#' message gives the exit code and quotes what the CLI wrote, after "The CLI
#' said:". The quoted text is the stderr text, or the stdout text if stderr
#' holds only whitespace and escape codes. A byte that is not valid UTF-8 shows as `<xx>`,
#' its hex value. ANSI escape codes, such as color codes, cursor codes, and
#' terminal links, are removed, and each run of whitespace becomes one space.
#' A text longer than 1000 characters keeps at most its last 1000
#' characters, after "…".
#'
#' @section Desktop Users: On desktop operating systems (macOS and Windows),
#'   running this command may actually launch the LM Studio desktop application
#'   to act as the backend engine. If the GUI is already open, this function
#'   will simply detect the active instance and return successfully. While safe
#'   to use, desktop users generally do not need to call this function and can
#'   just open the application manually.
#'
#' @seealso [LM Studio Headless Daemon
#'   (llmster)](https://lmstudio.ai/docs/developer/core/headless_llmster)
#'
#' @return Invisibly returns the CLI exit code, \code{0}.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' lms_daemon_start()
#' }
lms_daemon_start <- function() {
  args <- build_args_daemon_up()
  res <- processx::run(lms_path(), args, error_on_status = FALSE)

  if (res$status == 0) {
    rlm_alert_success("LM Studio daemon started in the background.")
  } else {
    rlm_abort_cli_run("Failed to start the LM Studio daemon.", res)
  }

  invisible(res$status)
}

#' Check the global status of LM Studio
#'
#' Displays the overall status of the LM Studio backend via the CLI, including loaded
#' models and the server state. This function works regardless of whether
#' the backend was started via the desktop GUI or the headless daemon.
#'
#' @return A character vector of the raw CLI output.
#' @export
#'
#' @examples
#' \dontrun{
#' lms_daemon_status()
#' }
lms_daemon_status <- function() {
  res <- processx::run(lms_path(), "status", error_on_status = FALSE)

  lines <- strsplit(res$stdout, "\r?\n")[[1]]
  lines <- cli::ansi_strip(lines)
  lines <- sub(".*\r", "", lines)
  lines <- lines[lines != ""]

  return(lines)
}

#' Build arguments for lms_daemon_stop
#' @noRd
#'
#' @examples
#' build_args_daemon_down()
build_args_daemon_down <- function() {
  c("daemon", "down")
}

#' Stop the LM Studio headless daemon
#'
#' Stops the `llmster` daemon via the CLI. Use this to clean up system resources when
#' you are completely finished using LM Studio in headless mode.
#'
#' If the CLI exits with a status other than 0, the function reads what the
#' CLI wrote. If the text says that the daemon is part of LM Studio, the
#' function prints an info message and returns `FALSE`. If the text says
#' that the daemon is not running, it prints an info message and returns
#' `TRUE`. Letter case does not matter. Any other failure aborts. The
#' message gives the exit code, quotes what the CLI wrote after "The CLI
#' said:", and gives a hint about `force = TRUE`. The quoted text is the
#' stderr text, or the stdout text if stderr holds only whitespace and
#' escape codes. A byte
#' that is not valid UTF-8 shows as `<xx>`, its hex value. ANSI escape
#' codes, such as color codes, cursor codes, and terminal links, are
#' removed, and each run of whitespace becomes one space. A text longer than
#' 1000 characters keeps at most its last 1000 characters, after "…".
#'
#' @section Desktop Users:
#' If the daemon is currently being managed by the LM Studio desktop
#' application, the CLI does not stop it. The CLI intentionally prevents
#' programmatic shutdowns of the GUI to avoid disrupting visual sessions.
#' This function then returns `FALSE`, and the daemon keeps running. In this
#' scenario, you must close the desktop application manually.
#'
#' @param force Logical. If `TRUE`, attempts to stop the local server before
#'   shutting down the daemon. The daemon cannot be stopped while the server
#'   is actively running. Defaults to `FALSE`. If no server is running, the
#'   message of [lms_server_stop()] says so.
#'
#' @return Invisibly returns `TRUE` if the daemon stopped or was not
#'   running, and `FALSE` if the LM Studio GUI manages it.
#' @export
#'
#' @examples
#' \dontrun{
#' lms_daemon_stop(force = TRUE)
#' }
lms_daemon_stop <- function(force = FALSE) {
  if (isTRUE(force)) {
    tryCatch(lms_server_stop(), error = function(e) NULL)
  }

  args <- build_args_daemon_down()
  res <- processx::run(lms_path(), args, error_on_status = FALSE)

  if (res$status == 0) {
    rlm_alert_success("LM Studio daemon stopped successfully.")
    return(invisible(TRUE))
  }

  # The phrases are read before the cut, so a long text still matches.
  # cli_output_clean() also makes a byte that is not valid UTF-8 safe for
  # grepl().
  text <- cli_output_clean(res)
  if (!is.null(text)) {
    # Catch the GUI conflict and exit gracefully
    if (grepl("part of LM Studio", text, ignore.case = TRUE)) {
      rlm_alert_info(
        "The daemon is managed by the LM Studio GUI and will remain running."
      )
      return(invisible(FALSE))
    }

    # Catch the "already stopped" scenario and exit gracefully
    if (grepl("not running", text, ignore.case = TRUE)) {
      rlm_alert_info("The LM Studio daemon is already stopped.")
      return(invisible(TRUE))
    }
  }

  # For all other errors, abort as usual
  rlm_abort_cli_run(
    "Failed to stop the LM Studio daemon.",
    res,
    text = text,
    hint = c(
      "i" = "Hint: If the server is still running, try `lms_daemon_stop(force = TRUE)` or run `lms_server_stop()` first."
    )
  )
}

#' Run code with the LM Studio daemon active
#'
#' Temporarily starts the LM Studio headless daemon, executes the provided
#' R expression, and then gracefully shuts the daemon and any active servers
#' down. This is ideal for automated scripts and pipelines.
#'
#' @section Desktop Users:
#' Be cautious using this wrapper if you already have the LM Studio GUI open.
#' While the setup phase (`lms_daemon_start`) will succeed, the teardown phase
#' (`lms_daemon_stop`) does not stop the daemon, because the CLI prevents
#' programmatic shutdowns of the graphical interface. The teardown prints an
#' info message, and the daemon keeps running. This wrapper is best reserved
#' for strictly headless environments or fully automated scripts.
#'
#' @param code An R expression to execute while the daemon is running.
#'
#' @return The result of the evaluated code.
#' @export
#'
#' @examples
#' \dontrun{
#' result <- with_lms_daemon({
#'   lms_load("llama-3.1-8b")
#'   lms_chat("llama-3.1-8b", input = "Hello world!")
#' })
#' }
with_lms_daemon <- function(code) {
  lms_daemon_start()

  on.exit(lms_daemon_stop(force = TRUE), add = TRUE)

  force(code)
}
