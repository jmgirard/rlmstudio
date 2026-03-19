#' Check if LM Studio CLI is installed
#'
#' @return Logical. TRUE if lms is found, FALSE otherwise.
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
#' @param min_version Character string of the required version. Default is "0.4.0".
#'
#' @return Logical. TRUE if the version is sufficient, FALSE otherwise.
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
#' @param method Character. Either "browser" or "headless".
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
    os <- Sys.info()[["sysname"]]

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

    tryCatch(
      {
        if (os %in% c("Darwin", "Linux")) {
          # Check if curl is available
          if (Sys.which("curl") == "") {
            cli::cli_abort(
              "The system command {.val curl} is required but was not found."
            )
          }

          processx::run(
            command = "bash",
            args = c(
              "-c",
              "set -o pipefail; curl -fsSL https://lmstudio.ai/install.sh | bash"
            ),
            echo_cmd = TRUE,
            echo = TRUE
          )
        } else if (os == "Windows") {
          processx::run(
            command = "powershell",
            args = c("-Command", "irm https://lmstudio.ai/install.ps1 | iex"),
            echo_cmd = TRUE,
            echo = TRUE
          )
        } else {
          cli::cli_abort(
            "Automatic installation is not supported for this operating system: {.val {os}}."
          )
        }

        rlm_alert_success("Installation script completed.")
        cli::cli_alert_warning(
          "You may need to restart your R session or terminal for the PATH changes to take effect."
        )
        rlm_alert_info(
          "In a headless environment, remember to start the daemon using {.fn lms_daemon_start} and the server using {.fn lms_server_start} before loading models."
        )
      },
      error = function(e) {
        cli::cli_abort(c(
          "x" = "Headless installation failed.",
          "i" = "Error message: {.val {e$message}}"
        ))
      }
    )
  }

  return(invisible(TRUE))
}
