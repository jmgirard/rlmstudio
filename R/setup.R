#' Check if LM Studio CLI is installed
#'
#' Uses the same lookup as [lms_path()]: the `RLMSTUDIO_LMS_PATH` environment
#' variable, then the system `PATH`, then common installation directories.
#'
#' @return A logical scalar: \code{TRUE} if [lms_path()] finds the \code{lms}
#'   executable, and \code{FALSE} if it aborts.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' has_lms()
#' }
has_lms <- function() {
  tryCatch(
    {
      lms_path()
      TRUE
    },
    error = function(e) FALSE
  )
}

#' Check if the installed LM Studio CLI meets the minimum requirement
#'
#' @param min_version Character string of the required version. Default is
#'   "0.4.0".
#'
#' @return A logical scalar: \code{TRUE} if the LM Studio CLI version meets or
#'   exceeds the specified \code{min_version}, and \code{FALSE} otherwise,
#'   including when [lms_path()] does not find the CLI.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' check_lms_version("0.4.0")
#' }
check_lms_version <- function(min_version = "0.4.0") {
  path <- tryCatch(lms_path(), error = function(e) NULL)
  if (is.null(path)) {
    cli::cli_alert_danger("LM Studio CLI is not installed.")
    return(FALSE)
  }

  tryCatch(
    {
      result <- processx::run(
        path,
        args = "--version",
        error_on_status = FALSE
      )
      output <- paste(result$stdout, result$stderr)

      if (grepl("CLI commit:", output, ignore.case = TRUE)) {
        rlm_alert_success(
          "LM Studio CLI is using the modern architecture (0.4.0+)."
        )
        return(TRUE)
      }

      version_string <- regmatches(
        output,
        regexpr("[0-9]+\\.[0-9]+\\.[0-9]+", output)
      )

      if (length(version_string) == 0) {
        cli::cli_alert_warning(c(
          "Could not parse the LM Studio CLI version. Output was: ",
          "{.val {trimws(output)}}"
        ))
        return(FALSE)
      }

      if (numeric_version(version_string) >= numeric_version(min_version)) {
        rlm_alert_success(
          "LM Studio CLI version {.val {version_string}} meets the requirement ({.val {min_version}})."
        )
        return(TRUE)
      } else {
        cli::cli_alert_danger(
          "LM Studio CLI version {.val {version_string}} is too old. Minimum required is {.val {min_version}}."
        )
        return(FALSE)
      }
    },
    error = function(e) {
      cli::cli_abort(c(
        "x" = "Failed to check LM Studio CLI version.",
        "i" = "Error message: {.val {e$message}}"
      ))
    }
  )
}

#' Help the user install or update LM Studio
#'
#' This function provides two methods for setting up LM Studio on your system.
#' The "browser" method opens the official download page for the LM Studio
#' desktop application (GUI). The "headless" method runs an automated
#' installation script to install the \code{llmster} daemon and CLI, which is
#' suitable for servers, containers, or users who prefer a GUI-less environment.
#'
#' If the headless installer exits with a status other than 0, the function
#' aborts. The message gives the exit code and quotes the installer output,
#' after "The installer said:". A byte that is not valid UTF-8 shows as
#' `<xx>`, its hex value. ANSI color codes, cursor codes, and terminal links
#' are removed, and each run of whitespace becomes one space. A text longer
#' than 1000 characters keeps at most its last 1000 characters, after "…".
#' Any other error of the install step,
#' such as a missing `curl`, aborts with "Headless installation failed." and
#' the error message.
#'
#' @param method Character. Either "browser" (opens the GUI download page) or
#'   "headless" (installs the \code{llmster} daemon via script).
#'
#' @return Invisibly returns \code{TRUE} upon successful completion. This
#'   function is primarily utilized for its side effects of opening a web
#'   browser or executing system installation commands.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Open your default web browser to the download page
#' install_lmstudio(method = "browser")
#'
#' # Attempt automatic headless installation via the command line
#' install_lmstudio(method = "headless")
#' }
install_lmstudio <- function(method = c("browser", "headless")) {
  method <- match.arg(method)

  # Check for existence AND version before proceeding
  if (has_lms() && check_lms_version("0.4.0")) {
    rlm_alert_success("Your LM Studio setup is ready to go!")
    return(invisible(TRUE))
  }

  if (method == "browser") {
    rlm_alert_info(
      "Opening the LM Studio download page in your default browser..."
    )
    utils::browseURL("https://lmstudio.ai/download")
    cli::cli_alert_warning(
      "Please install or update the software, restart R, and try again."
    )
  } else if (method == "headless") {
    # CRAN Compliance: Require interactive consent or explicit environment variable
    if (
      !interactive() &&
        !isTRUE(as.logical(Sys.getenv("RLMSTUDIO_ALLOW_INSTALL", "FALSE")))
    ) {
      cli::cli_abort(c(
        "Installation requires an interactive session to grant permission.",
        "i" = "To install automatically in non-interactive scripts or CI/CD, set the {.envvar RLMSTUDIO_ALLOW_INSTALL} environment variable to {.val TRUE}."
      ))
    }

    if (interactive()) {
      consent <- utils::askYesNo(
        "This will download and install the LM Studio CLI to your system. Do you want to proceed?"
      )
      if (!isTRUE(consent)) {
        cli::cli_abort("Installation cancelled by user.")
      }
    }

    os <- Sys.info()[["sysname"]]
    rlm_progress_step("Downloading and installing LM Studio CLI...")

    # The handler wraps any error of the install step, such as a missing
    # curl, an unsupported system, or a shell that fails to start. A run
    # that exits with a status other than 0 is checked after it, so its
    # abort reaches the user whole.
    res <- tryCatch(
      {
        if (os %in% c("Darwin", "Linux")) {
          if (Sys.which("curl") == "") {
            cli::cli_abort(
              "The system command {.val curl} is required but was not found."
            )
          }

          res <- processx::run(
            command = "bash",
            args = c(
              "-c",
              "set -o pipefail; curl -fsSL https://lmstudio.ai/install.sh | bash"
            ),
            echo = FALSE,
            stderr_to_stdout = TRUE,
            error_on_status = FALSE
          )
        } else if (os == "Windows") {
          res <- processx::run(
            command = "powershell",
            args = c("-Command", "irm https://lmstudio.ai/install.ps1 | iex"),
            echo = FALSE,
            stderr_to_stdout = TRUE,
            error_on_status = FALSE
          )
        } else {
          cli::cli_abort(
            "Automatic installation is not supported for this operating system: {.val {os}}."
          )
        }
        res
      },
      error = function(e) {
        cli::cli_progress_cleanup()
        cli::cli_abort(c(
          "x" = "Headless installation failed.",
          "i" = "Error message: {.val {e$message}}"
        ))
      }
    )

    if (res$status != 0) {
      cli::cli_progress_cleanup()
      # stderr_to_stdout = TRUE leaves stderr NULL, so the stdout text is
      # quoted.
      rlm_abort_cli_run(
        "Headless installation failed.",
        res,
        label = "The installer said"
      )
    }

    rlm_progress_done()
    rlm_alert_success("LM Studio CLI installed successfully.")
    rlm_alert_info(
      "In a headless environment, remember to start the daemon using {.fn lms_daemon_start} and the server using {.fn lms_server_start} before loading models."
    )
  }

  return(invisible(TRUE))
}
