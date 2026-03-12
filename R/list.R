#' List downloaded models
#'
#' @param llm Logical. Show only Large Language Models (LLMs). Defaults to FALSE.
#' @param embedding Logical. Show only embedding models. Defaults to FALSE.
#' @param detailed Logical. Show detailed information about each model. Defaults to FALSE.
#' @param json Logical. Output the list as a data frame. Defaults to TRUE.
#' @param host Character. The host address of the local server.
#'
#' @return A data frame of models if `json = TRUE`, otherwise a character vector.
#' @export
list_downloaded <- function(llm = FALSE,
                     embedding = FALSE,
                     detailed = FALSE,
                     json = TRUE,
                     host = "http://localhost:1234") {

  # Use the models manifest endpoint
  resp <- httr2::request(host) |>
    httr2::req_url_path("/api/v0/models") |>
    httr2::req_perform()

  # jsonlite::fromJSON is much better at binding lists with different lengths
  raw_content <- httr2::resp_body_string(resp)
  full_data <- jsonlite::fromJSON(raw_content, simplifyDataFrame = TRUE)
  df <- full_data$data

  if (is.null(df) || length(df) == 0) {
    return(data.frame())
  }

  # Apply filters
  if (isTRUE(llm)) df <- df[df$type == "llm", ]
  if (isTRUE(embedding)) df <- df[df$type == "embedding", ]

  # Select columns based on detailed argument
  if (!isTRUE(detailed) && nrow(df) > 0) {
    # We use intersect to avoid errors if some columns are missing from the API
    core_cols <- c("id", "type", "state", "sizeBytes", "architecture")
    available_cols <- intersect(core_cols, names(df))
    df <- df[, available_cols, drop = FALSE]
  }

  if (!isTRUE(json)) {
    return(utils::capture.output(print(df)))
  }

  df
}

#' List currently loaded models
#'
#' @param json Logical. Output the list as a data frame. Defaults to TRUE.
#' @param host Character. The host address of the local server.
#'
#' @return A data frame of loaded models if `json = TRUE`, otherwise a character vector.
#' @export
list_loaded <- function(json = TRUE, host = "http://localhost:1234") {

  # Fetch all models using the improved ls logic
  df <- list_downloaded(json = TRUE, detailed = TRUE, host = host)

  if (is.null(df) || nrow(df) == 0) {
    return(if (isTRUE(json)) data.frame() else "No models found.")
  }

  # Filter for 'loaded' state
  df_loaded <- df[df$state == "loaded", ]

  if (!isTRUE(json)) {
    if (nrow(df_loaded) == 0) return("No models loaded.")
    return(utils::capture.output(print(df_loaded)))
  }

  df_loaded
}
