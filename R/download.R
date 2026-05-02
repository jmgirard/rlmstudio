#' Download a model via REST API
#'
#' @param model Character. The model to download. Accepts model catalog
#'   identifiers (e.g., "openai/gpt-oss-20b") and exact Hugging Face links.
#' @param quantization Character. Optional. Quantization level of the model to
#'   download (e.g., "Q4_K_M"). Only supported for Hugging Face links.
#' @param host Character. The host address of the local server. Defaults to
#'   "http://localhost:1234".
#' @param ... Additional arguments passed to the request.
#'
#' @seealso [LM Studio Download Model
#'   API](https://lmstudio.ai/docs/developer/rest/download)
#'
#' @return A character string containing the download \code{job_id}, or
#'   \code{"already_downloaded"} if already downloaded.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#'
#' # Download a model by its HuggingFace identifier
#' job_id <- lms_download("google/gemma-3-1b")
#'
#' # Download with a specific quantization level
#' lms_download("google/gemma-3-1b", quantization = "4bit")
#' }
lms_download <- function(
  model,
  quantization = NULL,
  host = "http://localhost:1234",
  ...
) {
  if (!is_server_running()) {
    cli::cli_alert_danger(
      "The LM Studio server is not running. Run {.fn lms_server_start} first."
    )
    return(invisible(NULL))
  }

  if (is.null(model) || model == "") {
    cli::cli_abort("You must provide a valid model identifier or URL.")
  }

  body <- list(
    model = model,
    quantization = quantization
  )

  # Remove NULLs and merge any additional arguments from dots
  body <- Filter(Negate(is.null), body)
  body <- utils::modifyList(body, list(...))

  # Capture the step ID so we can manually close it later
  step_id <- rlm_progress_step(
    "Initiating download for model: {.val {model}}..."
  )

  resp <- lms_client(host) |>
    httr2::req_url_path("api/v1/models/download") |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  # Explicitly complete the progress step before printing subsequent alerts
  rlm_progress_done(step_id)

  if (httr2::resp_status(resp) == 200) {
    resp_data <- httr2::resp_body_json(resp)

    if (
      !is.null(resp_data$status) && resp_data$status == "already_downloaded"
    ) {
      rlm_alert_success("Model {.val {model}} is already downloaded.")
      return(invisible("already_downloaded"))
    }

    if (!is.null(resp_data$job_id)) {
      rlm_alert_success(
        "Download job started successfully. Job ID: {.val {resp_data$job_id}}"
      )
      return(resp_data$job_id)
    }

    rlm_alert_success("Download request succeeded.")
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

  cli::cli_abort(c("x" = "API Download Failed: {err_msg}"))
}

#' Get the status of a download job
#'
#' @param job_id Character. The unique identifier for the download job.
#' @param host Character. The host address of the local server. Defaults to
#'   "http://localhost:1234".
#'
#' @seealso [LM Studio Download Status
#'   API](https://lmstudio.ai/docs/developer/rest/download-status)
#'
#' @return An object of class \code{lms_download_status} containing the download
#'   status.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#'
#' job_id <- lms_download("google/gemma-3-1b")
#' status <- lms_download_status(job_id)
#' print(status)
#' }
lms_download_status <- function(job_id, host = "http://localhost:1234") {
  if (!is_server_running()) {
    cli::cli_alert_danger(
      "The LM Studio server is not running. Run {.fn lms_server_start} first."
    )
    return(invisible(NULL))
  }

  if (identical(job_id, "already_downloaded")) {
    out <- list(
      job_id = "N/A",
      status = "already_downloaded"
    )
    class(out) <- c("lms_download_status", "list")
    return(out)
  }

  if (is.null(job_id) || job_id == "") {
    cli::cli_abort("You must provide a valid job_id.")
  }

  resp <- lms_client(host) |>
    httr2::req_url_path(paste0("api/v1/models/download/status/", job_id)) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    out <- httr2::resp_body_json(resp)
    class(out) <- c("lms_download_status", "list")
    return(out)
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

  cli::cli_abort(c("x" = "API Status Request Failed: {err_msg}"))
}

#' Print method for LM Studio download status
#'
#' @param x An object of class \code{lms_download_status}.
#' @param ... Additional arguments passed to print.
#'
#' @keywords internal
#' @return Invisibly returns the input object \code{x}.
#' @export
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#'
#' job_id <- lms_download("google/gemma-3-1b")
#' status <- lms_download_status(job_id)
#' print(status)
#' }
print.lms_download_status <- function(x, ...) {
  cli::cli_h3("Download Job: {.val {x$job_id}}")

  # Color-code the status dynamically
  status_col <- switch(
    x$status,
    "downloading" = cli::col_blue,
    "completed" = cli::col_green,
    "already_downloaded" = cli::col_green,
    "failed" = cli::col_red,
    "error" = cli::col_red,
    cli::col_grey
  )

  cli::cli_text("{.strong Status:} ", status_col(x$status))

  # Calculate and format progress
  if (!is.null(x$total_size_bytes) && !is.null(x$downloaded_bytes)) {
    pct <- round((x$downloaded_bytes / x$total_size_bytes) * 100, 1)
    dl_gb <- round(x$downloaded_bytes / (1024^3), 2)
    tot_gb <- round(x$total_size_bytes / (1024^3), 2)

    cli::cli_text("{.strong Progress:} {pct}% ({dl_gb} GB / {tot_gb} GB)")
  }

  # Format speed
  if (!is.null(x$bytes_per_second) && x$bytes_per_second > 0) {
    spd_mb <- round(x$bytes_per_second / (1024^2), 2)
    cli::cli_text("{.strong Speed:} {spd_mb} MB/s")
  }

  # Invisible return so assignment still captures the underlying list
  invisible(x)
}
