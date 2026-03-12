#' Build arguments for model_load
#' @noRd
build_args_model_load <- function(model = NULL, ttl = NULL, gpu = NULL,
                                  context_length = NULL, parallel = NULL,
                                  identifier = NULL, estimate_only = FALSE,
                                  host = NULL) {
  args <- "load"

  if (!is.null(model)) args <- c(args, model)
  if (!is.null(ttl)) args <- c(args, "--ttl", as.character(ttl))

  if (!is.null(gpu)) {
    gpu_str <- as.character(gpu)
    if (tolower(gpu_str) != "auto") {
      args <- c(args, "--gpu", gpu_str)
    }
  }

  if (!is.null(context_length)) args <- c(args, "--context-length", as.character(context_length))
  if (!is.null(parallel)) args <- c(args, "--parallel", as.character(parallel))
  if (!is.null(identifier)) args <- c(args, "--identifier", identifier)
  if (isTRUE(estimate_only)) args <- c(args, "--estimate-only")
  if (!is.null(host)) args <- c(args, "--host", host)

  args
}

#' Load a model into memory
#'
#' Loads a specified model into LM Studio's memory. You can configure parameters
#' like context length, GPU offload, parallel processing, and time-to-live (TTL).
#'
#' @param model Character. The model key or path to load. If omitted, the CLI will prompt you.
#' @param ttl Integer. Unload the model after this many seconds of inactivity.
#' @param gpu Character or Numeric. GPU offload amount. Values can be "auto" (default), "max", "off", or a decimal between 0 and 1.
#' @param context_length Integer. The number of tokens to consider as context.
#' @param parallel Integer. The maximum number of concurrent requests the model can process simultaneously.
#' @param identifier Character. A custom identifier for the loaded model for API reference.
#' @param estimate_only Logical. Print a resource (memory) estimate and exit without loading the model. Defaults to FALSE.
#' @param host Character. The host address of a remote LM Studio instance.
#'
#' @return Invisibly returns the system exit code (0 for success).
#' @export
model_load <- function(model = NULL, ttl = NULL, gpu = NULL,
                       context_length = NULL, parallel = NULL,
                       identifier = NULL, estimate_only = FALSE, host = NULL) {

  args <- build_args_model_load(model = model,
                                ttl = ttl,
                                gpu = gpu,
                                context_length = context_length,
                                parallel = parallel,
                                identifier = identifier,
                                estimate_only = estimate_only,
                                host = host)

  if (is.null(model)) {
    res <- processx::run("lms", args, stdout = "", stderr = "", error_on_status = FALSE)
  } else {
    res <- processx::run("lms", args, error_on_status = FALSE)
  }

  if (res$status == 0) {
    if (isTRUE(estimate_only)) {
      cli::cli_alert_success("Memory estimation completed successfully.")
    } else {
      cli::cli_alert_success("Model loaded successfully.")

      if (!is.null(model) && !is.na(res$stdout)) {
        lines <- strsplit(res$stdout, "\r?\n")[[1]]
        api_tip <- grep("identifier", lines, value = TRUE, ignore.case = TRUE)
        if (length(api_tip) > 0) {
          cli::cli_bullets(c("i" = cli::ansi_strip(trimws(api_tip[1]))))
        }
      }
    }
  } else {
    if (!is.null(model) && (!is.na(res$stderr) || !is.na(res$stdout))) {
      err_lines <- strsplit(paste(res$stderr, res$stdout, sep = "\n"), "\r?\n")[[1]]
      err_lines <- cli::ansi_strip(err_lines)
      err_lines <- err_lines[err_lines != ""]

      cli::cli_abort(c(
        "Failed to load model. Exit code: {.val {res$status}}.",
        "x" = paste(err_lines, collapse = "\n")
      ), call = NULL)
    } else {
      cli::cli_abort("Failed to load model. Exit code: {.val {res$status}}.", call = NULL)
    }
  }

  invisible(res$status)
}

#' Build arguments for model_unload
#' @noRd
build_args_model_unload <- function(model = NULL, all = FALSE, host = NULL) {
  args <- "unload"

  if (!is.null(model)) args <- c(args, model)
  if (isTRUE(all)) args <- c(args, "--all")
  if (!is.null(host)) args <- c(args, "--host", host)

  args
}

#' Unload a model from memory
#'
#' Removes a specific model or all currently loaded models from LM Studio's memory.
#'
#' @param model Character. The key of the model to unload. If omitted and `all = FALSE`, the CLI will prompt you.
#' @param all Logical. Unload all currently loaded models. Defaults to FALSE.
#' @param host Character. The host address of a remote LM Studio instance.
#'
#' @return Invisibly returns the system exit code (0 for success).
#' @export
#'
#' @examples
#' \dontrun{
#' # Unload a specific model
#' model_unload("llama-3.1-8b")
#'
#' # Unload all loaded models
#' model_unload(all = TRUE)
#' }
model_unload <- function(model = NULL, all = FALSE, host = NULL) {

  args <- build_args_model_unload(model = model, all = all, host = host)

  res <- processx::run("lms", args, stdout = "", stderr = "", error_on_status = FALSE)

  if (res$status == 0) {
    cli::cli_alert_success("Model(s) unloaded successfully.")
  } else {
    cli::cli_abort("Failed to unload model(s). Exit code: {.val {res$status}}.")
  }

  invisible(res$status)
}

#' Build arguments for model_import
#' @noRd
build_args_model_import <- function(file_path, user_repo = NULL, yes = FALSE,
                                    action = c("move", "copy", "hard-link", "symbolic-link"),
                                    dry_run = FALSE) {
  args <- c("import", file_path)

  if (!is.null(user_repo)) args <- c(args, "--user-repo", user_repo)
  if (isTRUE(yes)) args <- c(args, "--yes")
  if (isTRUE(dry_run)) args <- c(args, "--dry-run")

  action <- match.arg(action)
  if (action == "copy") {
    args <- c(args, "--copy")
  } else if (action == "hard-link") {
    args <- c(args, "--hard-link")
  } else if (action == "symbolic-link") {
    args <- c(args, "--symbolic-link")
  }

  args
}

#' Import a local model file
#'
#' Imports an existing model file into your LM Studio models directory. This is
#' useful for bringing in models without downloading them again.
#'
#' @param file_path Character. Path to the model file to import.
#' @param user_repo Character. Set the target folder as <user>/<repo>. Skips categorization prompts.
#' @param yes Logical. Skip confirmations and try to infer the model location from the file name.
#' @param action Character. How to handle the file: "move" (default), "copy", "hard-link", or "symbolic-link".
#' @param dry_run Logical. Do not perform the import, just print what would be done.
#'
#' @return Invisibly returns the system exit code (0 for success).
#' @export
#'
#' @examples
#' \dontrun{
#' # Dry run an import to see where it would go
#' model_import("path/to/model.gguf", dry_run = TRUE)
#'
#' # Import a model by copying it into a specific user repository
#' model_import("path/to/model.gguf", action = "copy", user_repo = "my-org/custom-models")
#' }
model_import <- function(file_path, user_repo = NULL, yes = FALSE,
                         action = c("move", "copy", "hard-link", "symbolic-link"),
                         dry_run = FALSE) {

  if (missing(file_path) || !file.exists(file_path)) {
    cli::cli_abort("The {.arg file_path} must be a valid, existing file path.")
  }

  args <- build_args_model_import(file_path = file_path,
                                  user_repo = user_repo,
                                  yes = yes,
                                  action = action,
                                  dry_run = dry_run)

  res <- processx::run("lms", args, stdout = "", stderr = "", error_on_status = FALSE)

  if (res$status == 0) {
    if (isTRUE(dry_run)) {
      cli::cli_alert_success("Model import dry run completed successfully.")
    } else {
      cli::cli_alert_success("Model imported successfully.")
    }
  } else {
    cli::cli_abort("Failed to import model. Exit code: {.val {res$status}}.")
  }

  invisible(res$status)
}
