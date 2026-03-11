#' Build arguments for model_ls
#' @noRd
build_args_model_ls <- function(llm = FALSE, embedding = FALSE, detailed = FALSE,
                                json = FALSE, host = NULL) {
  args <- "ls"
  if (isTRUE(llm)) args <- c(args, "--llm")
  if (isTRUE(embedding)) args <- c(args, "--embedding")
  if (isTRUE(detailed)) args <- c(args, "--detailed")
  if (isTRUE(json)) args <- c(args, "--json")
  if (!is.null(host)) args <- c(args, "--host", host)
  args
}

#' List downloaded models
#'
#' Displays a list of all models downloaded to your LM Studio machine, including
#' their size, architecture, and parameters.
#'
#' @param llm Logical. Show only Large Language Models (LLMs). Defaults to FALSE.
#' @param embedding Logical. Show only embedding models. Defaults to FALSE.
#' @param detailed Logical. Show detailed information about each model. Defaults to FALSE.
#' @param json Logical. Output the list in machine-readable JSON format and parse it into an R object. Defaults to FALSE.
#' @param host Character. The host address of a remote LM Studio instance to connect to.
#'
#' @return A character vector of the raw CLI output. If `json = TRUE` and the
#'   `jsonlite` package is installed, it returns a parsed list or data frame of the models.
#' @export
#'
#' @examples
#' \dontrun{
#' # List all models
#' model_ls()
#'
#' # List only LLMs and return as a data frame
#' my_llms <- model_ls(llm = TRUE, json = TRUE)
#' }
model_ls <- function(llm = FALSE, embedding = FALSE, detailed = FALSE,
                     json = FALSE, host = NULL) {

  args <- build_args_model_ls(llm = llm, embedding = embedding, detailed = detailed,
                              json = json, host = host)

  res <- processx::run("lms", args, error_on_status = FALSE)

  # Split output into lines and clean ANSI codes/carriage returns
  lines <- strsplit(res$stdout, "\r?\n")[[1]]
  lines <- cli::ansi_strip(lines)
  lines <- gsub("\r", "", lines)
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

#' Build arguments for model_ps
#' @noRd
build_args_model_ps <- function(json = FALSE, host = NULL) {
  args <- "ps"
  if (isTRUE(json)) args <- c(args, "--json")
  if (!is.null(host)) args <- c(args, "--host", host)
  args
}

#' List currently loaded models
#'
#' Displays information about all models currently loaded into memory by LM Studio.
#'
#' @param json Logical. Output the list in machine-readable JSON format and parse it into an R object. Defaults to FALSE.
#' @param host Character. The host address of a remote LM Studio instance to connect to.
#'
#' @return A character vector of the raw CLI output. If `json = TRUE` and the
#'   `jsonlite` package is installed, it returns a parsed list or data frame of loaded models.
#' @export
#'
#' @examples
#' \dontrun{
#' # See what is loaded in the console
#' model_ps()
#'
#' # Get loaded models as a data frame
#' active_models <- model_ps(json = TRUE)
#' }
model_ps <- function(json = FALSE, host = NULL) {

  args <- build_args_model_ps(json = json, host = host)

  res <- processx::run("lms", args, error_on_status = FALSE)

  # Split output into lines and clean ANSI codes/carriage returns
  lines <- strsplit(res$stdout, "\r?\n")[[1]]
  lines <- cli::ansi_strip(lines)
  lines <- gsub("\r", "", lines)
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

#' Build arguments for model_get
#' @noRd
build_args_model_get <- function(model_name = NULL,
                                 mlx = FALSE,
                                 gguf = FALSE,
                                 limit = NULL,
                                 always_show_all_results = FALSE,
                                 always_show_download_options = FALSE) {
  args <- "get"

  if (!is.null(model_name)) args <- c(args, model_name)
  if (isTRUE(mlx)) args <- c(args, "--mlx")
  if (isTRUE(gguf)) args <- c(args, "--gguf")
  if (!is.null(limit)) args <- c(args, "--limit", as.character(limit))
  if (isTRUE(always_show_all_results)) args <- c(args, "--always-show-all-results")
  if (isTRUE(always_show_download_options)) args <- c(args, "-a")

  args
}

#' Search and download models
#'
#' Searches for and downloads models from online repositories via the LM Studio CLI.
#' If no model name is specified, it shows staff-picked recommendations.
#'
#' @details This function is interactive. It will print search results and download
#'   progress directly to your R console. If multiple matches are found, it may
#'   prompt you to choose one.
#'
#' @param model_name Character. The model to search for or download. For models
#'   with multiple quantizations, append '@' (e.g., "llama-3.1-8b@q4_k_m").
#' @param mlx Logical. Include only MLX models in search results.
#' @param gguf Logical. Include only GGUF models in search results.
#' @param limit Integer. Limit the number of model options shown in search results.
#' @param always_show_all_results Logical. Always prompt you to choose from search
#'   results, even when there is an exact match.
#' @param always_show_download_options Logical. Always prompt you to choose a
#'   quantization, even when an exact match is auto-selected.
#'
#' @return Invisibly returns the system exit code (0 for success).
#' @export
#'
#' @examples
#' \dontrun{
#' # Show staff-picked recommendations
#' model_get()
#'
#' # Search for a specific model
#' model_get("llama-3.1-8b")
#'
#' # Download an exact quantization and limit search results
#' model_get("llama-3.1-8b@q4_k_m", limit = 5)
#' }
model_get <- function(model_name = NULL,
                      mlx = FALSE,
                      gguf = FALSE,
                      limit = NULL,
                      always_show_all_results = FALSE,
                      always_show_download_options = FALSE) {

  args <- build_args_model_get(model_name = model_name,
                               mlx = mlx,
                               gguf = gguf,
                               limit = limit,
                               always_show_all_results = always_show_all_results,
                               always_show_download_options = always_show_download_options)

  res <- processx::run("lms", args, stdout = "", stderr = "", error_on_status = FALSE)

  if (res$status == 0) {
    cli::cli_alert_success("Model download process completed successfully.")
  } else {
    cli::cli_abort("Model download failed or was interrupted. Exit code: {.val {res$status}}.")
  }

  invisible(res$status)
}

#' Build arguments for model_load
#' @noRd
build_args_model_load <- function(model = NULL, ttl = NULL, gpu = NULL,
                                  context_length = NULL, identifier = NULL,
                                  estimate_only = FALSE, host = NULL) {
  args <- "load"

  if (!is.null(model)) args <- c(args, model)
  if (!is.null(ttl)) args <- c(args, "--ttl", as.character(ttl))
  if (!is.null(gpu)) args <- c(args, "--gpu", as.character(gpu))
  if (!is.null(context_length)) args <- c(args, "--context-length", as.character(context_length))
  if (!is.null(identifier)) args <- c(args, "--identifier", identifier)
  if (isTRUE(estimate_only)) args <- c(args, "--estimate-only")
  if (!is.null(host)) args <- c(args, "--host", host)

  args
}

#' Load a model into memory
#'
#' Loads a specified model into LM Studio's memory. You can configure parameters
#' like context length, GPU offload, and time-to-live (TTL).
#'
#' @param model Character. The model key or path to load. If omitted, the CLI will prompt you.
#' @param ttl Integer. Unload the model after this many seconds of inactivity.
#' @param gpu Character or Numeric. GPU offload amount. Values can be "max", "off", "auto", or a decimal between 0 and 1.
#' @param context_length Integer. The number of tokens to consider as context.
#' @param identifier Character. A custom identifier for the loaded model for API reference.
#' @param estimate_only Logical. Print a resource (memory) estimate and exit without loading the model. Defaults to FALSE.
#' @param host Character. The host address of a remote LM Studio instance.
#'
#' @return Invisibly returns the system exit code (0 for success).
#' @export
#'
#' @examples
#' \dontrun{
#' # Load a model with specific GPU offload and context length
#' model_load("llama-3.1-8b", gpu = "max", context_length = 4096)
#'
#' # Estimate memory usage without loading
#' model_load("llama-3.1-8b", estimate_only = TRUE)
#' }
model_load <- function(model = NULL, ttl = NULL, gpu = NULL,
                       context_length = NULL, identifier = NULL,
                       estimate_only = FALSE, host = NULL) {

  args <- build_args_model_load(model = model,
                                ttl = ttl,
                                gpu = gpu,
                                context_length = context_length,
                                identifier = identifier,
                                estimate_only = estimate_only,
                                host = host)

  res <- processx::run("lms", args, stdout = "", stderr = "", error_on_status = FALSE)

  if (res$status == 0) {
    if (isTRUE(estimate_only)) {
      cli::cli_alert_success("Memory estimation completed successfully.")
    } else {
      cli::cli_alert_success("Model loaded successfully.")
    }
  } else {
    cli::cli_abort("Failed to load model. Exit code: {.val {res$status}}.")
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
