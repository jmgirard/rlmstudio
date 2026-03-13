#' Download a model via REST API
#'
#' @param model Character. The model to download. Accepts model catalog identifiers
#'   (e.g., "openai/gpt-oss-20b") and exact Hugging Face links.
#' @param quantization Character. Optional. Quantization level of the model to download
#'   (e.g., "Q4_K_M"). Only supported for Hugging Face links.
#' @param host Character. The host address of the local server. Defaults to "http://localhost:1234".
#' @param ... Additional arguments passed to the request.
#'
#' @return A character string containing the download \code{job_id}, or \code{NULL} if already downloaded.
#' @export
lms_download <- function(model, quantization = NULL, host = "http://localhost:1234", ...) {
  if (!is_server_running()) {
    cli::cli_abort("The LM Studio server is not running. Run {.fn start_server} first.")
  }

  if (is.null(model) || model == "") {
    cli::cli_abort("You must provide a valid model identifier or URL.")
  }

  endpoint <- paste0(host, "/api/v1/models/download")

  body <- list(
    model = model,
    quantization = quantization
  )

  body <- Filter(Negate(is.null), body)

  cli::cli_progress_step("Initiating download for model: {.val {model}}...")

  resp <- httr2::request(endpoint) |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    resp_data <- httr2::resp_body_json(resp)

    if (!is.null(resp_data$status) && resp_data$status == "already_downloaded") {
      cli::cli_alert_success("Model {.val {model}} is already downloaded.")
      return(invisible(NULL))
    }

    if (!is.null(resp_data$job_id)) {
      cli::cli_alert_success("Download job started successfully. Job ID: {.val {resp_data$job_id}}")
      return(resp_data$job_id)
    }

    cli::cli_alert_success("Download request succeeded.")
    return(invisible(TRUE))
  }

  err_msg <- tryCatch(httr2::resp_body_json(resp)$error$message, error = function(e) "Unknown Error")
  cli::cli_abort(c("x" = "API Download Failed: {err_msg}"))
}

#' Get the status of a download job
#'
#' @param job_id Character. The unique identifier for the download job.
#' @param host Character. The host address of the local server. Defaults to "http://localhost:1234".
#'
#' @return A list containing the download status and related metadata.
#' @export
lms_download_status <- function(job_id, host = "http://localhost:1234") {
  if (!is_server_running()) {
    cli::cli_abort("The LM Studio server is not running. Run {.fn start_server} first.")
  }

  if (is.null(job_id) || job_id == "") {
    cli::cli_abort("You must provide a valid job_id.")
  }

  endpoint <- paste0(host, "/api/v1/models/download/status/", job_id)

  resp <- httr2::request(endpoint) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    return(httr2::resp_body_json(resp))
  }

  err_msg <- tryCatch(httr2::resp_body_json(resp)$error$message, error = function(e) "Unknown Error")
  cli::cli_abort(c("x" = "API Status Request Failed: {err_msg}"))
}
