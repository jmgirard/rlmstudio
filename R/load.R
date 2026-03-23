#' Load a model via REST API
#'
#' @param model Character. Unique identifier for the model to load.
#' @param context_length Integer. Maximum number of tokens that the model will
#'   consider.
#' @param eval_batch_size Integer. Number of input tokens to process together in
#'   a single batch during evaluation.
#' @param flash_attention Logical. Whether to optimize attention computation.
#' @param num_experts Integer. Number of experts to use during inference for MoE
#'   models.
#' @param offload_kv_cache_to_gpu Logical. Whether KV cache is offloaded to GPU
#'   memory.
#' @param echo_load_config Logical. If \code{TRUE}, echoes the final load
#'   configuration in the response.
#' @param force Logical. If \code{TRUE}, bypasses the check for currently loaded
#'   models and requests a new instance from the server. Note that this does not
#'   overwrite or replace the existing model; it loads a second concurrent
#'   instance into VRAM. Defaults to \code{FALSE}.
#' @param host Character. The host address of the local server. Defaults to
#'   "http://localhost:1234".
#' @param ... Additional arguments passed to the API request body (useful for
#'   future API parameters).
#'
#' @seealso [LM Studio Load Model
#'   API](https://lmstudio.ai/docs/developer/rest/load)
#'
#' @return Invisibly returns the model identifier string on success, or the load
#'   configuration list if \code{echo_load_config = TRUE}.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#' lms_download("google/gemma-3-1b")
#'
#' # Load a model with default settings
#' lms_load("google/gemma-3-1b")
#'
#' # Load a model with custom context length and flash attention enabled
#' lms_load("google/gemma-3-1b", context_length = 8192, flash_attention = TRUE)
#' }
lms_load <- function(
  model,
  context_length = NULL,
  eval_batch_size = NULL,
  flash_attention = NULL,
  num_experts = NULL,
  offload_kv_cache_to_gpu = NULL,
  echo_load_config = FALSE,
  force = FALSE,
  host = "http://localhost:1234",
  ...
) {
  if (!is_server_running()) {
    cli::cli_abort(
      "The LM Studio server is not running. Run {.fn lms_server_start} first.",
      call = NULL
    )
  }

  # Check if the model is already loaded to prevent redundant API calls
  if (!isTRUE(force)) {
    active_models <- list_models(
      loaded = TRUE,
      detailed = TRUE,
      quiet = TRUE,
      host = host
    )

    if (nrow(active_models) > 0 && model %in% active_models$key) {
      rlm_alert_info(
        "Model {.val {model}} is already loaded. Use {.code force = TRUE} to load an additional instance."
      )
      if (isTRUE(echo_load_config)) {
        cli::cli_alert_warning(
          "Cannot echo load config because the model was already loaded."
        )
      }
      return(invisible(model))
    }
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

  rlm_progress_step(
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
      return(invisible(model))
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
  cli::cli_abort(c("x" = "API Load Failed: {err_msg}"), call = NULL)
}
