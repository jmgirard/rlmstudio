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
