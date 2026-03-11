#' List installed inference runtimes
#'
#' Displays a list of all installed LM Studio inference runtimes (e.g., llama.cpp, mlx).
#'
#' @param json Logical. Attempt to output the list in JSON format and parse it. Defaults to FALSE.
#'
#' @return A character vector of the raw CLI output. If `json = TRUE` and the CLI
#'   supports it, returns a parsed data frame or list.
#' @export
#'
#' @examples
#' \dontrun{
#' runtime_ls()
#' }
runtime_ls <- function(json = FALSE) {
  args <- c("runtime", "ls")

  if (isTRUE(json)) {
    args <- c(args, "--json")
  }

  res <- system2("lms", args = args, stdout = TRUE)

  if (isTRUE(json)) {
    tryCatch({
      return(jsonlite::fromJSON(paste(res, collapse = "\n")))
    }, error = function(e) {
      cli::cli_warn("Failed to parse JSON output. Returning raw character vector instead.")
      return(res)
    })
  }

  return(res)
}

#' Download an inference runtime
#'
#' Downloads a new LM Studio inference runtime. If no runtime is specified,
#' it will prompt you interactively to select one.
#'
#' @param runtime Character. The name of the runtime to download (e.g., "llama.cpp").
#'
#' @return Invisibly returns the system exit code (0 for success).
#' @export
#'
#' @examples
#' \dontrun{
#' # Open interactive selection menu
#' runtime_get()
#' }
runtime_get <- function(runtime = NULL) {
  args <- c("runtime", "get")
  if (!is.null(runtime)) args <- c(args, runtime)

  status <- system2("lms", args = args)

  if (status == 0) {
    cli::cli_alert_success("Runtime downloaded successfully.")
  } else {
    cli::cli_abort("Failed to download runtime. Exit code: {.val {status}}.")
  }
  invisible(status)
}

#' Set the active inference runtime
#'
#' Switches the currently active LM Studio inference runtime. If no runtime is
#' specified, it will prompt you interactively to choose a version.
#'
#' @param runtime Character. The name of the runtime to select.
#'
#' @return Invisibly returns the system exit code (0 for success).
#' @export
#'
#' @examples
#' \dontrun{
#' runtime_select("llama.cpp")
#' }
runtime_select <- function(runtime = NULL) {
  args <- c("runtime", "select")
  if (!is.null(runtime)) args <- c(args, runtime)

  status <- system2("lms", args = args)

  if (status == 0) {
    cli::cli_alert_success("Runtime selected successfully.")
  } else {
    cli::cli_abort("Failed to select runtime. Exit code: {.val {status}}.")
  }
  invisible(status)
}

#' Update an installed runtime
#'
#' Checks for and installs updates for a specific inference runtime.
#'
#' @param runtime Character. The name of the runtime to update (e.g., "llama.cpp", "mlx").
#'
#' @return Invisibly returns the system exit code (0 for success).
#' @export
#'
#' @examples
#' \dontrun{
#' runtime_update("llama.cpp")
#' }
runtime_update <- function(runtime = NULL) {
  args <- c("runtime", "update")
  if (!is.null(runtime)) args <- c(args, runtime)

  status <- system2("lms", args = args)

  if (status == 0) {
    cli::cli_alert_success("Runtime updated successfully.")
  } else {
    cli::cli_abort("Failed to update runtime. Exit code: {.val {status}}.")
  }
  invisible(status)
}

#' Uninstall an inference runtime
#'
#' Removes a previously installed inference runtime from your LM Studio setup.
#'
#' @param runtime Character. The name of the runtime to remove.
#'
#' @return Invisibly returns the system exit code (0 for success).
#' @export
#'
#' @examples
#' \dontrun{
#' runtime_remove("mlx")
#' }
runtime_remove <- function(runtime = NULL) {
  args <- c("runtime", "remove")
  if (!is.null(runtime)) args <- c(args, runtime)

  status <- system2("lms", args = args)

  if (status == 0) {
    cli::cli_alert_success("Runtime removed successfully.")
  } else {
    cli::cli_abort("Failed to remove runtime. Exit code: {.val {status}}.")
  }
  invisible(status)
}
