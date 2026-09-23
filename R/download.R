#' Download a model via REST API
#'
#' @param model Character. The model to download. Accepts model catalog
#'   identifiers (e.g., "openai/gpt-oss-20b") and exact Hugging Face links.
#'   Must be one name, given as a single string.
#' @param quantization Character. Optional. Quantization level of the model to
#'   download (e.g., "Q4_K_M"). Only supported for Hugging Face links.
#' @param host Character. The host address of the local server. Defaults to
#'   "http://localhost:1234".
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#' @param ... Additional arguments passed to the request.
#'
#' @seealso [LM Studio Download Model
#'   API](https://lmstudio.ai/docs/developer/rest/download)
#'
#' @return A character string containing the download \code{job_id}, or
#'   \code{"already_downloaded"}, invisibly, if the model is already
#'   downloaded. The call aborts with \code{rlmstudio_bad_response} when the
#'   reply holds neither a \code{job_id} string nor the status
#'   \code{"already_downloaded"}. It also aborts when the reply is not a JSON
#'   object whose \code{status} is a string.
#'
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
#' @inheritSection rlmstudio-conditions Malformed response
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
  ...,
  token = NULL
) {
  rlm_check_id(model, "model")

  stop_if_no_server(host)

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

  resp <- lms_client(host, token = token) |>
    httr2::req_url_path("api/v1/models/download") |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  # Explicitly complete the progress step before printing subsequent alerts
  rlm_progress_done(step_id)

  if (httr2::resp_status(resp) == 200) {
    resp_data <- parse_ok_body(resp, "API Download Failed")
    fault <- download_reply_fault(resp_data)
    if (!is.null(fault)) {
      rlm_abort_bad_reply(resp, "API Download Failed", fault, "a download reply")
    }

    if (identical(resp_data[["status"]], "already_downloaded")) {
      rlm_alert_success("Model {.val {model}} is already downloaded.")
      return(invisible("already_downloaded"))
    }

    job_id <- resp_data[["job_id"]]
    rlm_alert_success(
      "Download job started successfully. Job ID: {.val {job_id}}"
    )
    return(job_id)
  }

  rlm_abort_api(resp, "API Download Failed", !is.null(rlm_token(token)))
}

#' Find the first way a download reply breaks its shape rules
#'
#' The body is a JSON object whose `status` is a string. Unless `status` is
#' `"already_downloaded"`, its `job_id` is a string too. The rules check types
#' and not status values, so a status that a later LM Studio adds still passes
#' (D-017). Fields are read by exact name.
#'
#' @param body The body, parsed with `simplifyVector = FALSE`.
#' @return `NULL` when the body passes, or one clause naming the fault.
#'
#' @noRd
download_reply_fault <- function(body) {
  if (!is_json_object(body)) {
    return("the response body is not a JSON object.")
  }
  if (!is_json_string(body[["status"]])) {
    return("`status` is not a string.")
  }
  if (identical(body[["status"]], "already_downloaded")) {
    return(NULL)
  }
  if (!is_json_string(body[["job_id"]])) {
    return("`job_id` is not a string.")
  }
  NULL
}

#' Get the status of a download job
#'
#' @param job_id Character. The unique identifier for the download job. Must be
#'   one id, given as a single string.
#' @param host Character. The host address of the local server. Defaults to
#'   "http://localhost:1234".
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#'
#' @seealso [LM Studio Download Status
#'   API](https://lmstudio.ai/docs/developer/rest/download-status)
#'
#' @return An object of class \code{lms_download_status} containing the download
#'   status.
#'
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
#' @inheritSection rlmstudio-conditions Malformed response
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
lms_download_status <- function(
  job_id,
  host = "http://localhost:1234",
  token = NULL
) {
  rlm_check_id(job_id, "job_id")

  stop_if_no_server(host)

  if (identical(job_id, "already_downloaded")) {
    out <- list(
      job_id = "N/A",
      status = "already_downloaded"
    )
    class(out) <- c("lms_download_status", "list")
    return(out)
  }

  resp <- lms_client(host, token = token) |>
    httr2::req_url_path(paste0("api/v1/models/download/status/", job_id)) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    out <- parse_ok_body(resp, "API Status Request Failed")
    fault <- download_status_fault(out)
    if (!is.null(fault)) {
      rlm_abort_bad_reply(
        resp,
        "API Status Request Failed",
        fault,
        "a download status"
      )
    }
    class(out) <- c("lms_download_status", "list")
    return(out)
  }

  rlm_abort_api(resp, "API Status Request Failed", !is.null(rlm_token(token)))
}

#' Find the first way a download status breaks its shape rules
#'
#' The body is a JSON object whose `job_id` and `status` are strings. Its
#' `total_size_bytes`, `downloaded_bytes`, and `bytes_per_second` are each a
#' number, or absent, or `null`. These are the fields that
#' `print.lms_download_status()` reads. Fields are read by exact name (D-017).
#'
#' @param body The body, parsed with `simplifyVector = FALSE`.
#' @return `NULL` when the body passes, or one clause naming the fault.
#'
#' @noRd
download_status_fault <- function(body) {
  if (!is_json_object(body)) {
    return("the response body is not a JSON object.")
  }
  for (field in c("job_id", "status")) {
    if (!is_json_string(body[[field]])) {
      return(paste0("`", field, "` is not a string."))
    }
  }
  for (field in c("total_size_bytes", "downloaded_bytes", "bytes_per_second")) {
    value <- body[[field]]
    if (!is.null(value) && !is_json_number(value)) {
      return(paste0("`", field, "` is not a number."))
    }
  }
  NULL
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
  # Fields are read with `[[`, which matches exact names only. `$` would read
  # a field whose name extends the one asked for.
  job_id <- x[["job_id"]]
  status <- x[["status"]]
  total <- x[["total_size_bytes"]]
  downloaded <- x[["downloaded_bytes"]]
  speed <- x[["bytes_per_second"]]

  cli::cli_h3("Download Job: {.val {job_id}}")

  # Color-code the status dynamically
  status_col <- switch(
    status,
    "downloading" = cli::col_blue,
    "completed" = cli::col_green,
    "already_downloaded" = cli::col_green,
    "failed" = cli::col_red,
    "error" = cli::col_red,
    cli::col_grey
  )

  # The status is spliced in as a value. Passed as a separate argument, cli
  # would read its braces as code to run.
  status_text <- status_col(status)
  cli::cli_text("{.strong Status:} {status_text}")

  # Calculate and format progress
  if (!is.null(total) && !is.null(downloaded)) {
    pct <- round((downloaded / total) * 100, 1)
    dl_gb <- round(downloaded / (1024^3), 2)
    tot_gb <- round(total / (1024^3), 2)

    cli::cli_text("{.strong Progress:} {pct}% ({dl_gb} GB / {tot_gb} GB)")
  }

  # Format speed
  if (!is.null(speed) && speed > 0) {
    spd_mb <- round(speed / (1024^2), 2)
    cli::cli_text("{.strong Speed:} {spd_mb} MB/s")
  }

  # Invisible return so assignment still captures the underlying list
  invisible(x)
}
