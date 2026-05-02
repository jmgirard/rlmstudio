#' Check if LM Studio CLI is installed
#'
#' @return A logical scalar: \code{TRUE} if the \code{lms} executable is found
#'   on the system path, and \code{FALSE} otherwise.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' has_lms()
#' }
has_lms <- function() {
  Sys.which("lms") != ""
}

#' Check if the installed LM Studio CLI meets the minimum requirement
#'
#' @param min_version Character string of the required version. Default is
#'   "0.4.0".
#'
#' @return A logical scalar: \code{TRUE} if the LM Studio CLI version meets or
#'   exceeds the specified \code{min_version}, and \code{FALSE} otherwise.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' check_lms_version("0.4.0")
#' }
check_lms_version <- function(min_version = "0.4.0") {
  if (!has_lms()) {
    cli::cli_alert_danger("LM Studio CLI is not installed.")
    return(FALSE)
  }

  tryCatch(
    {
      result <- processx::run(
        lms_path(),
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

    tryCatch(
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

        if (res$status == 0) {
          rlm_progress_done()
          rlm_alert_success("LM Studio CLI installed successfully.")
        } else {
          cli::cli_progress_cleanup()
          cli::cli_abort(c(
            "x" = "Headless installation failed. Exit code: {.val {res$status}}.",
            "i" = "CLI output: {.val {trimws(res$stdout)}}"
          ))
        }

        rlm_alert_info(
          "In a headless environment, remember to start the daemon using {.fn lms_daemon_start} and the server using {.fn lms_server_start} before loading models."
        )
      },
      error = function(e) {
        cli::cli_progress_cleanup()
        cli::cli_abort(c(
          "x" = "Headless installation failed.",
          "i" = "Error message: {.val {e$message}}"
        ))
      }
    )
  }

  return(invisible(TRUE))
}
