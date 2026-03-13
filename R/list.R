#' List available models
#'
#' Retrieves a list of models available on your system via the LM Studio REST API.
#'
#' @param loaded Logical. If \code{TRUE}, returns only currently loaded models. Defaults to \code{FALSE}.
#' @param type Character vector. The types of models to include. Defaults to \code{c("llm", "embedding")}.
#' @param detailed Logical. Show all information about each model. Defaults to \code{FALSE}.
#' @param host Character. The host address of the local server.
#'
#' @return A data frame of model information.
#' @export
list_models <- function(loaded = FALSE,
                        type = c("llm", "embedding"),
                        detailed = FALSE,
                        host = "http://localhost:1234") {

  resp <- httr2::request(host) |>
    httr2::req_url_path("/api/v1/models") |>
    httr2::req_perform()

  raw_content <- httr2::resp_body_string(resp)
  full_data <- jsonlite::fromJSON(raw_content, simplifyDataFrame = TRUE)
  df <- full_data$models

  if (is.null(df) || length(df) == 0 || nrow(df) == 0) {
    return(if (isTRUE(json)) data.frame() else "No models found.")
  }

  # Apply type filters
  df <- df[df$type %in% type, , drop = FALSE]

  # Evaluate load state for all matching models
  if (nrow(df) > 0) {
    df$state <- ifelse(
      vapply(df$loaded_instances, function(x) {
        if (is.data.frame(x)) nrow(x) > 0 else length(x) > 0
      }, logical(1)),
      "loaded",
      "unloaded"
    )

    # Apply loaded filter
    if (isTRUE(loaded)) {
      df <- df[df$state == "loaded", , drop = FALSE]
    }
  }

  if (nrow(df) == 0) {
    return(if (isTRUE(json)) data.frame() else "No models found matching criteria.")
  }

  # Format size for readability
  if ("size_bytes" %in% names(df)) {
    df$size_gb <- round(df$size_bytes / (1024^3), 2)
  }

  # Clean up and select columns
  if (!isTRUE(detailed)) {
    core_cols <- c("state", "type", "display_name", "key", "architecture", "size_gb")
    available_cols <- intersect(core_cols, names(df))
    df <- df[, available_cols, drop = FALSE]
  } else {
    # Drop the complex list column for easier printing even in detailed view
    df$loaded_instances <- NULL
  }

  return(df)
}
