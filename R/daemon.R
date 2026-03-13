#' Build arguments for lms_daemon_start
#' @noRd
build_args_daemon_up <- function() {
  c("daemon", "up")
}

#' Start the LM Studio headless daemon
#'
#' Launches the `llmster` daemon in the background via the CLI. This is required in
#' headless environments (such as Linux servers) before loading models or
#' starting the local server.
#'
#' @section Desktop Users:
#' On desktop operating systems (macOS and Windows), running this command may
#' actually launch the LM Studio desktop application to act as the backend engine.
#' If the GUI is already open, this function will simply detect the active
#' instance and return successfully. While safe to use, desktop users generally
#' do not need to call this function and can just open the application manually.
#'
#' @seealso [LM Studio Headless Daemon (llmster)](https://lmstudio.ai/docs/developer/core/headless_llmster)
#'
#' @return Invisibly returns the process object (or 0 if already running).
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
    cli::cli_alert_success("LM Studio daemon started in the background.")
  } else {
    cli::cli_abort(
      "Failed to start the LM Studio daemon. Exit code: {.val {res$status}}."
    )
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
build_args_daemon_down <- function() {
  c("daemon", "down")
}

#' Stop the LM Studio headless daemon
#'
#' Stops the `llmster` daemon via the CLI. Use this to clean up system resources when
#' you are completely finished using LM Studio in headless mode.
#'
#' @section Desktop Users:
#' If the daemon is currently being managed by the LM Studio desktop
#' application, this function will fail. The CLI intentionally prevents
#' programmatic shutdowns of the GUI to avoid disrupting visual sessions.
#' In this scenario, you must close the desktop application manually.
#'
#' @param force Logical. If `TRUE`, attempts to stop the local server before
#'   shutting down the daemon. The daemon cannot be stopped while the server
#'   is actively running. Defaults to `FALSE`.
#'
#' @return Invisibly returns the system exit code (0 for success).
#' @export
#'
#' @examples
#' \dontrun{
#' lms_daemon_stop(force = TRUE)
#' }
lms_daemon_stop <- function(force = FALSE) {
  if (isTRUE(force)) {
    # Attempt to stop the server first, suppressing errors
    tryCatch(lms_server_stop(), error = function(e) NULL)
  }

  args <- build_args_daemon_down()
  res <- processx::run(lms_path(), args, error_on_status = FALSE)

  if (res$status == 0) {
    cli::cli_alert_success("LM Studio daemon stopped successfully.")
  } else {
    err_msg <- trimws(res$stderr)
    if (err_msg == "") {
      err_msg <- trimws(res$stdout)
    }
    if (err_msg == "") {
      err_msg <- "Unknown CLI error."
    }

    if (grepl("part of LM Studio", err_msg, ignore.case = TRUE)) {
      cli::cli_abort(c(
        "Cannot stop the daemon because it is running as part of the LM Studio GUI.",
        "i" = "Please close the desktop application manually."
      ))
    }

    cli::cli_abort(c(
      "Failed to stop the LM Studio daemon. Exit code: {.val {res$status}}.",
      "x" = "CLI output: {.val {err_msg}}",
      "i" = "Hint: If the server is still running, try `lms_daemon_stop(force = TRUE)` or run `lms_server_stop()` first."
    ))
  }

  invisible(res$status)
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
#' (`lms_daemon_stop`) will fail because the CLI prevents programmatic shutdowns
#' of the graphical interface. This wrapper is best reserved for strictly
#' headless environments or fully automated scripts.
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
