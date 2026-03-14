#' List available models
#'
#' Retrieves a list of models available on your system via the LM Studio REST API.
#'
#' @param loaded Logical. If \code{TRUE}, returns only currently loaded models. Defaults to \code{FALSE}.
#' @param type Character vector. The types of models to include. Defaults to \code{c("llm", "embedding")}.
#' @param detailed Logical. Show all information about each model. Defaults to \code{FALSE}.
#' @param quiet Logical. If \code{TRUE}, suppresses informative console messages. Defaults to \code{FALSE}.
#' @param host Character. The host address of the local server.
#'
#' @seealso [LM Studio List Models API](https://lmstudio.ai/docs/developer/rest/list)
#'
#' @return A data frame of model information.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#' lms_download("google/gemma-3-1b")
#' lms_load("google/gemma-3-1b")
#'
#' # List all downloaded models
#' list_models()
#'
#' # List only currently loaded models
#' list_models(loaded = TRUE)
#'
#' # Get detailed information about loaded text models
#' list_models(loaded = TRUE, type = "llm", detailed = TRUE)
#' }
list_models <- function(
  loaded = FALSE,
  type = c("llm", "embedding"),
  detailed = FALSE,
  quiet = FALSE,
  host = "http://localhost:1234"
) {
  if (!is_server_running()) {
    if (!quiet) {
      cli::cli_alert_danger(
        "The LM Studio server is not running. Run {.fn lms_server_start} first."
      )
    }
    return(invisible(data.frame()))
  }

  resp <- lms_client(host) |>
    httr2::req_url_path("api/v1/models") |>
    httr2::req_perform()

  raw_content <- httr2::resp_body_string(resp)
  full_data <- jsonlite::fromJSON(raw_content, simplifyDataFrame = TRUE)
  df <- full_data$models

  if (is.null(df) || nrow(df) == 0) {
    if (!quiet) {
      rlm_inform(c("i" = "No models found on host {.url {host}}."))
    }
    return(invisible(data.frame()))
  }

  # Apply type filters
  df <- df[df$type %in% type, , drop = FALSE]

  # Evaluate load state for all matching models
  if (nrow(df) > 0) {
    df$state <- ifelse(
      vapply(
        df$loaded_instances,
        function(x) {
          if (is.data.frame(x)) nrow(x) > 0 else length(x) > 0
        },
        logical(1)
      ),
      "loaded",
      "unloaded"
    )

    # Apply loaded filter
    if (isTRUE(loaded)) {
      df <- df[df$state == "loaded", , drop = FALSE]
    }
  }

  if (nrow(df) == 0) {
    if (!quiet) {
      rlm_inform(c(
        "!" = "No models found matching criteria: loaded = {.val {loaded}}, type = {.val {type}}."
      ))
    }
    return(invisible(data.frame()))
  }

  # Format size for readability
  if ("size_bytes" %in% names(df)) {
    df$size_gb <- round(df$size_bytes / (1024^3), 2)
  }

  # Clean up and select columns
  if (!isTRUE(detailed)) {
    core_cols <- c(
      "state",
      "type",
      "display_name",
      "key",
      "architecture",
      "size_gb"
    )
    available_cols <- intersect(core_cols, names(df))
    df <- df[, available_cols, drop = FALSE]
  }

  return(df)
}
