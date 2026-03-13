#' Load a model via REST API
#'
#' @param model Character. Unique identifier for the model to load.
#' @param context_length Integer. Maximum number of tokens that the model will consider.
#' @param eval_batch_size Integer. Number of input tokens to process together in a single batch during evaluation.
#' @param flash_attention Logical. Whether to optimize attention computation.
#' @param num_experts Integer. Number of experts to use during inference for MoE models.
#' @param offload_kv_cache_to_gpu Logical. Whether KV cache is offloaded to GPU memory.
#' @param echo_load_config Logical. If \code{TRUE}, echoes the final load configuration in the response.
#' @param host Character. The host address of the local server. Defaults to "http://localhost:1234".
#' @param ... Additional arguments passed to the API request body (useful for future API parameters).
#'
#' @seealso [LM Studio Load Model API](https://lmstudio.ai/docs/developer/rest/load)
#'
#' @return Invisibly returns \code{TRUE} on success, or the load configuration list if \code{echo_load_config = TRUE}.
#' @export
lms_load <- function(
  model,
  context_length = NULL,
  eval_batch_size = NULL,
  flash_attention = NULL,
  num_experts = NULL,
  offload_kv_cache_to_gpu = NULL,
  echo_load_config = FALSE,
  host = "http://localhost:1234",
  ...
) {
  if (!is_server_running()) {
    cli::cli_alert_danger(
      "The LM Studio server is not running. Run {.fn lms_server_start} first."
    )
    return(invisible(FALSE))
  }

  # 1. Build the explicit body based on current known parameters
  body <- list(
    model = model,
    context_length = if (!is.null(context_length)) {
      as.integer(context_length)
    } else {
      NULL
    },
    eval_batch_size = if (!is.null(eval_batch_size)) {
      as.integer(eval_batch_size)
    } else {
      NULL
    },
    flash_attention = if (!is.null(flash_attention)) {
      as.logical(flash_attention)
    } else {
      NULL
    },
    num_experts = if (!is.null(num_experts)) as.integer(num_experts) else NULL,
    offload_kv_cache_to_gpu = if (!is.null(offload_kv_cache_to_gpu)) {
      as.logical(offload_kv_cache_to_gpu)
    } else {
      NULL
    },
    echo_load_config = if (isTRUE(echo_load_config)) TRUE else NULL
  )

  # 2. Merge dots into the body (allows for future/undocumented API parameters)
  body <- utils::modifyList(Filter(Negate(is.null), body), list(...))

  cli::cli_progress_step(
    msg = "Loading model: {.val {model}}...",
    msg_done = "Model {.val {model}} loaded and verified."
  )

  resp <- lms_client(host) |>
    httr2::req_url_path("api/v1/models/load") |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    resp_data <- httr2::resp_body_json(resp)
    if (identical(resp_data$status, "loaded")) {
      if (isTRUE(echo_load_config)) {
        return(invisible(resp_data$load_config))
      }
      return(invisible(TRUE))
    }
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
  cli::cli_abort(c("x" = "API Load Failed: {err_msg}"))
}
