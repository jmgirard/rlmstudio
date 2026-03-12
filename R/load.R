#' Load a model via REST API
#' @export
lms_load <- function(model, context_length = NULL, ...) {
  if (!is_server_running()) {
    cli::cli_abort("The LM Studio server is not running. Run {.fn server_start} first.")
  }

  endpoint <- "http://localhost:1234/api/v1/models/load"
  body <- list(model = model)
  if (!is.null(context_length)) body$context_length <- as.integer(context_length)

  cli::cli_progress_step("Loading model: {.val {model}}...")

  resp <- httr2::request(endpoint) |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    # Verify the model is actually loaded in the API manifest
    verify_resp <- httr2::request("http://localhost:1234/api/v0/models") |> httr2::req_perform()
    models_data <- httr2::resp_body_json(verify_resp)$data
    is_loaded <- any(vapply(models_data, function(x) x$id == model && x$state == "loaded", logical(1)))

    if (is_loaded) {
      cli::cli_alert_success("Model {.val {model}} loaded and verified.")
      return(invisible(TRUE))
    }
  }

  err_msg <- tryCatch(httr2::resp_body_json(resp)$error$message, error = function(e) "Unknown Error")
  cli::cli_abort(c("x" = "API Load Failed: {err_msg}"))
}

#' Unload a model from memory
#' @export
lms_unload <- function(model) {

  if (is.null(model)) {
    cli::cli_abort("You must provide a model identifier.")
  }

  endpoint <- "http://localhost:1234/api/v1/models/unload"
  body <- list(instance_id = model)

  resp <- httr2::request(endpoint) |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    cli::cli_alert_success("Model {.val {model}} unloaded successfully.")
    return(invisible(TRUE))
  } else {
    err_msg <- tryCatch(httr2::resp_body_json(resp)$error$message, error = function(e) "Unknown Error")
    cli::cli_abort(c("x" = "API Unload Failed: {err_msg}"))
  }
}
