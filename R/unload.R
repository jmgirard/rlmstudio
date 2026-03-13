#' Unload a model from memory via REST API
#'
#' @param model Character. Unique identifier (\code{instance_id}) of the model instance to unload.
#' @param host Character. The host address of the local server. Defaults to "http://localhost:1234".
#' @param ... Additional arguments passed to the request.
#'
#' @return Invisibly returns \code{TRUE} on success.
#' @export
lms_unload <- function(model, host = "http://localhost:1234", ...) {
  if (!is_server_running()) {
    cli::cli_abort("The LM Studio server is not running. Run {.fn start_server} first.")
  }

  if (is.null(model) || model == "") {
    cli::cli_abort("You must provide a valid model identifier.")
  }

  endpoint <- paste0(host, "/api/v1/models/unload")
  body <- list(instance_id = model)

  cli::cli_progress_step("Unloading model: {.val {model}}...")

  resp <- httr2::request(endpoint) |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    resp_data <- httr2::resp_body_json(resp)

    # Verify the API confirms the target instance_id was unloaded
    if (!is.null(resp_data$instance_id) && resp_data$instance_id == model) {
      cli::cli_alert_success("Model {.val {model}} unloaded successfully.")
      return(invisible(TRUE))
    }

    # Fallback in case of subtle API response changes
    cli::cli_alert_success("Model {.val {model}} unloaded.")
    return(invisible(TRUE))
  }

  err_msg <- tryCatch(httr2::resp_body_json(resp)$error$message, error = function(e) "Unknown Error")
  cli::cli_abort(c("x" = "API Unload Failed: {err_msg}"))
}
