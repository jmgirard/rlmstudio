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
