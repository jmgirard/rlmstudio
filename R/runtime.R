#' Build arguments for runtime_ls
#' @noRd
build_args_runtime_ls <- function(json = FALSE) {
  args <- c("runtime", "ls")

  if (isTRUE(json)) {
    args <- c(args, "--json")
  }

  args
}

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
  args <- build_args_runtime_ls(json = json)

  res <- processx::run("lms", args, error_on_status = FALSE)

  # Split output into lines and clean ANSI codes/carriage returns
  lines <- strsplit(res$stdout, "\r?\n")[[1]]
  lines <- cli::ansi_strip(lines)
  lines <- sub(".*\r", "", lines)
  lines <- lines[lines != ""]

  if (isTRUE(json)) {
    tryCatch({
      return(jsonlite::fromJSON(paste(lines, collapse = "\n")))
    }, error = function(e) {
      cli::cli_warn("Failed to parse JSON output. Returning raw character vector instead.")
      return(lines)
    })
  }

  return(lines)
}

#' Build arguments for runtime_get
#' @noRd
build_args_runtime_get <- function(runtime = NULL) {
  args <- c("runtime", "get")
  if (!is.null(runtime)) args <- c(args, runtime)
  args
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
  args <- build_args_runtime_get(runtime = runtime)

  res <- processx::run("lms", args, stdout = "", stderr = "", error_on_status = FALSE)

  if (res$status == 0) {
    cli::cli_alert_success("Runtime downloaded successfully.")
  } else {
    cli::cli_abort("Failed to download runtime. Exit code: {.val {res$status}}.")
  }

  invisible(res$status)
}

#' Build arguments for runtime_select
#' @noRd
build_args_runtime_select <- function(runtime = NULL) {
  args <- c("runtime", "select")
  if (!is.null(runtime)) args <- c(args, runtime)
  args
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
  args <- build_args_runtime_select(runtime = runtime)

  res <- processx::run("lms", args, stdout = "", stderr = "", error_on_status = FALSE)

  if (res$status == 0) {
    cli::cli_alert_success("Runtime selected successfully.")
  } else {
    cli::cli_abort("Failed to select runtime. Exit code: {.val {res$status}}.")
  }

  invisible(res$status)
}

#' Build arguments for runtime_update
#' @noRd
build_args_runtime_update <- function(runtime = NULL) {
  args <- c("runtime", "update")
  if (!is.null(runtime)) args <- c(args, runtime)
  args
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
  args <- build_args_runtime_update(runtime = runtime)

  res <- processx::run("lms", args, stdout = "", stderr = "", error_on_status = FALSE)

  if (res$status == 0) {
    cli::cli_alert_success("Runtime updated successfully.")
  } else {
    cli::cli_abort("Failed to update runtime. Exit code: {.val {res$status}}.")
  }

  invisible(res$status)
}

#' Build arguments for runtime_remove
#' @noRd
build_args_runtime_remove <- function(runtime = NULL) {
  args <- c("runtime", "remove")
  if (!is.null(runtime)) args <- c(args, runtime)
  args
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
  args <- build_args_runtime_remove(runtime = runtime)

  res <- processx::run("lms", args, stdout = "", stderr = "", error_on_status = FALSE)

  if (res$status == 0) {
    cli::cli_alert_success("Runtime removed successfully.")
  } else {
    cli::cli_abort("Failed to remove runtime. Exit code: {.val {res$status}}.")
  }

  invisible(res$status)
}
