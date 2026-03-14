#' Unload a model from memory via REST API
#'
#' @param model Character. Unique identifier (\code{instance_id}) of the model instance to unload.
#' @param host Character. The host address of the local server. Defaults to "http://localhost:1234".
#' @param ... Additional arguments passed to the API request body.
#'
#' @note
#' If you have loaded multiple instances of the same model using \code{force = TRUE} in \code{lms_load()},
#' the server assigns them unique instance identifiers (e.g., \code{"google/gemma-3-1b"} and \code{"google/gemma-3-1b:2"}).
#' Passing the base model name to \code{lms_unload()} will only unload the primary instance.
#' To unload duplicate instances, you must provide their exact \code{instance_id}, or use \code{lms_unload_all()} to clear everything.
#'
#' @seealso [LM Studio Unload Model API](https://lmstudio.ai/docs/developer/rest/unload)
#'
#' @return Invisibly returns the model identifier string on success.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#' lms_download("google/gemma-3-1b")
#' lms_load("google/gemma-3-1b")
#'
#' # Unload a single specific model
#' lms_unload("google/gemma-3-1b")
#' }
lms_unload <- function(model, host = "http://localhost:1234", ...) {
  if (!is_server_running()) {
    cli::cli_abort(
      "The LM Studio server is not running. Run {.fn lms_server_start} first.",
      call = NULL
    )
  }

  # Build body and merge extra args from dots
  body <- utils::modifyList(list(instance_id = model), list(...))

  rlm_progress_step(
    msg = "Unloading model: {.val {model}}...",
    msg_done = "Model {.val {model}} unloaded successfully."
  )

  resp <- lms_client(host) |>
    httr2::req_url_path("api/v1/models/unload") |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    return(invisible(model))
  }

  err_msg <- tryCatch(
    {
      err_json <- httr2::resp_body_json(resp)
      if (!is.null(err_json$error$message)) {
        err_json$error$message
      } else if (!is.null(err_json$error)) {
        err_json$error
      } else {
        httr2::resp_body_string(resp)
      }
    },
    error = function(e) httr2::resp_body_string(resp)
  )

  if (err_msg == "") {
    err_msg <- paste("HTTP Status", httr2::resp_status(resp))
  }

  cli::cli_abort(c("x" = "API Unload Failed: {err_msg}"), call = NULL)
}

#' Unload all models from memory
#'
#' Retrieves a list of all currently loaded models and unloads them one by one.
#'
#' @param host Character. The host address of the local server. Defaults to "http://localhost:1234".
#' @param ... Additional arguments passed to the API request body for each unload request.
#'
#' @seealso \code{\link{lms_unload}}
#'
#' @return Invisibly returns a character vector of the unloaded model instance identifiers, or \code{NULL} if no models were loaded.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#' lms_download("google/gemma-3-1b")
#' lms_load("google/gemma-3-1b")
#'
#' # Unload all currently loaded models to clear VRAM
#' lms_unload_all()
#' }
lms_unload_all <- function(host = "http://localhost:1234", ...) {
  if (!is_server_running()) {
    cli::cli_abort(
      "The LM Studio server is not running. Run {.fn lms_server_start} first.",
      call = NULL
    )
  }

  # Fetch currently active models
  active_models <- list_models(
    loaded = TRUE,
    detailed = TRUE,
    quiet = TRUE,
    host = host
  )

  # Check if there is anything to unload
  if (nrow(active_models) == 0 || is.null(active_models$loaded_instances)) {
    rlm_alert_info("No models are currently loaded.")
    return(invisible(NULL))
  }

  # Robustly extract all instance IDs from the nested list column
  loaded_keys <- unlist(lapply(active_models$loaded_instances, function(x) {
    if (is.data.frame(x)) {
      # The API typically uses 'identifier' or 'id' for the specific instance string
      if ("identifier" %in% names(x)) {
        return(x$identifier)
      }
      if ("id" %in% names(x)) {
        return(x$id)
      }
      return(as.character(x[[1]])) # Fallback to the first column
    } else {
      return(as.character(x))
    }
  }))

  # Filter out any potential NAs or empty strings just to be safe
  loaded_keys <- Filter(function(x) !is.na(x) && x != "", loaded_keys)

  if (length(loaded_keys) == 0) {
    rlm_alert_info("No models are currently loaded.")
    return(invisible(NULL))
  }

  rlm_alert_info(
    "Found {length(loaded_keys)} loaded model instance{?s}. Unloading now..."
  )

  # Loop through and unload each specific instance
  for (instance_id in loaded_keys) {
    lms_unload(model = instance_id, host = host, ...)
  }

  rlm_alert_success("All models unloaded successfully.")

  return(invisible(loaded_keys))
}
