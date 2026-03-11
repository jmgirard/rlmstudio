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

  args <- c("ls")

  if (isTRUE(llm)) {
    args <- c(args, "--llm")
  }

  if (isTRUE(embedding)) {
    args <- c(args, "--embedding")
  }

  if (isTRUE(detailed)) {
    args <- c(args, "--detailed")
  }

  if (isTRUE(json)) {
    args <- c(args, "--json")
  }

  if (!is.null(host)) {
    args <- c(args, "--host", host)
  }

  res <- system2(
    command = "lms",
    args = args,
    stdout = TRUE
  )

  # The lms CLI can sometimes return a non-zero exit code if no models are found,
  # or it might just return empty JSON. We handle parsing safely here.
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

  args <- c("ps")

  if (isTRUE(json)) {
    args <- c(args, "--json")
  }

  if (!is.null(host)) {
    args <- c(args, "--host", host)
  }

  res <- system2(
    command = "lms",
    args = args,
    stdout = TRUE
  )

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

  args <- c("get")

  if (!is.null(model_name)) {
    args <- c(args, model_name)
  }

  if (isTRUE(mlx)) {
    args <- c(args, "--mlx")
  }

  if (isTRUE(gguf)) {
    args <- c(args, "--gguf")
  }

  if (!is.null(limit)) {
    args <- c(args, "--limit", as.character(limit))
  }

  if (isTRUE(always_show_all_results)) {
    args <- c(args, "--always-show-all-results")
  }

  if (isTRUE(always_show_download_options)) {
    args <- c(args, "-a")
  }

  status <- system2(
    command = "lms",
    args = args
  )

  if (status == 0) {
    cli::cli_alert_success("Model download process completed successfully.")
  } else {
    cli::cli_abort("Model download failed or was interrupted. Exit code: {.val {status}}.")
  }

  invisible(status)
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
  args <- c("load")

  if (!is.null(model)) {
    args <- c(args, model)
  }
  if (!is.null(ttl)) {
    args <- c(args, "--ttl", as.character(ttl))
  }
  if (!is.null(gpu)) {
    args <- c(args, "--gpu", as.character(gpu))
  }
  if (!is.null(context_length)) {
    args <- c(args, "--context-length", as.character(context_length))
  }
  if (!is.null(identifier)) {
    args <- c(args, "--identifier", identifier)
  }
  if (isTRUE(estimate_only)) {
    args <- c(args, "--estimate-only")
  }
  if (!is.null(host)) {
    args <- c(args, "--host", host)
  }

  # Allow the CLI to print progress bars and interactive prompts
  status <- system2("lms", args = args)

  if (status == 0) {
    if (isTRUE(estimate_only)) {
      cli::cli_alert_success("Memory estimation completed successfully.")
    } else {
      cli::cli_alert_success("Model loaded successfully.")
    }
  } else {
    cli::cli_abort("Failed to load model. Exit code: {.val {status}}.")
  }

  invisible(status)
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
  args <- c("unload")

  if (!is.null(model)) {
    args <- c(args, model)
  }
  if (isTRUE(all)) {
    args <- c(args, "--all")
  }
  if (!is.null(host)) {
    args <- c(args, "--host", host)
  }

  status <- system2("lms", args = args)

  if (status == 0) {
    cli::cli_alert_success("Model(s) unloaded successfully.")
  } else {
    cli::cli_abort("Failed to unload model(s). Exit code: {.val {status}}.")
  }

  invisible(status)
}
