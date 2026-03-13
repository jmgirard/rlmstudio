#' Load a model via REST API
#'
#' @param model Character. Unique identifier for the model to load.
#' @param context_length Integer. Maximum number of tokens that the model will consider.
#' @param eval_batch_size Integer. Number of input tokens to process together in a single batch during evaluation.
#' @param flash_attention Logical. Whether to optimize attention computation.
#' @param num_experts Integer. Number of experts to use during inference for MoE (Mixture of Experts) models.
#' @param offload_kv_cache_to_gpu Logical. Whether KV cache is offloaded to GPU memory.
#' @param echo_load_config Logical. If \code{TRUE}, echoes the final load configuration in the response.
#' @param host Character. The host address of the local server. Defaults to "http://localhost:1234".
#' @param ... Additional arguments passed to the request.
#'
#' @return Invisibly returns \code{TRUE} on success, or the load configuration list if \code{echo_load_config = TRUE}.
#' @export
lms_load <- function(model,
                     context_length = NULL,
                     eval_batch_size = NULL,
                     flash_attention = NULL,
                     num_experts = NULL,
                     offload_kv_cache_to_gpu = NULL,
                     echo_load_config = FALSE,
                     host = "http://localhost:1234",
                     ...) {

  if (!is_server_running()) {
    cli::cli_abort("The LM Studio server is not running. Run {.fn start_server} first.")
  }

  endpoint <- paste0(host, "/api/v1/models/load")

  # Build the request body with the explicit v1 options
  body <- list(
    model = model,
    context_length = if (!is.null(context_length)) as.integer(context_length) else NULL,
    eval_batch_size = if (!is.null(eval_batch_size)) as.integer(eval_batch_size) else NULL,
    flash_attention = if (!is.null(flash_attention)) as.logical(flash_attention) else NULL,
    num_experts = if (!is.null(num_experts)) as.integer(num_experts) else NULL,
    offload_kv_cache_to_gpu = if (!is.null(offload_kv_cache_to_gpu)) as.logical(offload_kv_cache_to_gpu) else NULL,
    echo_load_config = if (isTRUE(echo_load_config)) TRUE else NULL
  )

  # Remove NULLs so the API uses its own defaults
  body <- Filter(Negate(is.null), body)

  cli::cli_progress_step("Loading model: {.val {model}} . . .")

  resp <- httr2::request(endpoint) |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    resp_data <- httr2::resp_body_json(resp)

    # Verify the API reports the status as loaded
    if (identical(resp_data$status, "loaded")) {

      # Optional double-check with the models manifest (v1)
      verify_resp <- httr2::request(paste0(host, "/api/v1/models")) |> httr2::req_perform()
      models_data <- httr2::resp_body_json(verify_resp)$models

      # Look for the model key and ensure it has active loaded instances
      is_loaded <- any(vapply(models_data, function(x) {
        identical(x$key, model) && length(x$loaded_instances) > 0
      }, logical(1)))

      if (is_loaded) {
        cli::cli_alert_success("Model {.val {model}} loaded and verified.")

        # Return load configuration if requested
        if (isTRUE(echo_load_config) && !is.null(resp_data$load_config)) {
          return(invisible(resp_data$load_config))
        }
        return(invisible(TRUE))
      }
    }
  }

  err_msg <- tryCatch(httr2::resp_body_json(resp)$error$message, error = function(e) "Unknown Error")
  cli::cli_abort(c("x" = "API Load Failed: {err_msg}"))
}
