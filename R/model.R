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
