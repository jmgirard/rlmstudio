#' Unload a model from memory via REST API
#'
#' @param model Character. Unique identifier (\code{instance_id}) of the model instance to unload.
#' @param host Character. The host address of the local server. Defaults to "http://localhost:1234".
#' @param ... Additional arguments passed to the API request body.
#'
#' @return Invisibly returns \code{TRUE} on success.
#' @export
lms_unload <- function(model, host = "http://localhost:1234", ...) {
  if (!is_server_running()) {
    cli::cli_abort(
      "The LM Studio server is not running. Run {.fn lms_server_start} first."
    )
  }

  endpoint <- paste0(host, "/api/v1/models/unload")

  # Build body and merge extra args from dots
  body <- utils::modifyList(list(instance_id = model), list(...))

  cli::cli_progress_step(
    msg = "Unloading model: {.val {model}}...",
    msg_done = "Model {.val {model}} unloaded successfully."
  )

  resp <- httr2::request(endpoint) |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    return(invisible(TRUE))
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
  cli::cli_abort(c("x" = "API Unload Failed: {err_msg}"))
}
