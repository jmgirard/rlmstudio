#' Load a model via REST API
#'
#' @param model Character. Unique identifier for the model to load. Must be
#'   one name, given as a single string. The string must be valid in its
#'   declared encoding and not marked `"bytes"`. A class, names, and the S4
#'   bit are removed before the name is sent.
#' @param context_length Integer. Maximum number of tokens that the model will
#'   consider. A value above the maximum in the model list gives a warning.
#'   See the "Long prompts" section.
#' @param eval_batch_size Integer. Number of input tokens to process together in
#'   a single batch during evaluation.
#' @param flash_attention `TRUE`, `FALSE`, or `NULL`. Whether to optimize
#'   attention computation. `NULL`, the default, leaves the field out of the
#'   request. Any other value, `NA` and `"true"` included, aborts before the
#'   check for a running server.
#' @param num_experts Integer. Number of experts to use during inference for MoE
#'   models.
#' @param offload_kv_cache_to_gpu `TRUE`, `FALSE`, or `NULL`. Whether KV cache
#'   is offloaded to GPU memory. `NULL`, the default, leaves the field out of
#'   the request. Any other value, `NA` and `"true"` included, aborts before
#'   the check for a running server.
#' @param echo_load_config `TRUE` or `FALSE`. If \code{TRUE}, echoes the final
#'   load configuration in the response. Any other value, `NULL` and `NA`
#'   included, aborts before the check for a running server.
#' @param force `TRUE` or `FALSE`. If \code{TRUE}, bypasses the check for
#'   currently loaded models and requests a new instance from the server. Note
#'   that this does not overwrite or replace the existing model; it loads a
#'   second concurrent instance into VRAM. Defaults to \code{FALSE}. Any other
#'   value, `NULL` and `NA` included, aborts before the check for a running
#'   server.
#' @param host Character. The host address of the local server. Defaults to
#'   "http://localhost:1234".
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#' @param ... Additional arguments passed to the API request body (useful for
#'   future API parameters).
#'
#' @seealso [LM Studio Load Model
#'   API](https://lmstudio.ai/docs/developer/rest/load)
#'
#' @return Invisibly returns a character string of the loaded model identifier
#'   upon success, also when the model was already loaded. It is a plain
#'   string, with no class, names, or S4 bit. If \code{echo_load_config = TRUE}
#'   and this call loads the model, it instead invisibly
#'   returns a list containing the model's detailed load configuration.
#'
#' @section Long prompts:
#' A prompt longer than the context length of the loaded model fails. On LM
#' Studio 0.4.25+1, with google/gemma-3-1b loaded at a `context_length` of
#' 512, the `/v1/responses` and `/api/v1/chat` routes answered a longer prompt
#' with status 500. The `/v1/chat/completions` route answered it with status
#' 400. Each message began "The number of tokens to keep from the initial
#' prompt is greater than the context length". The chat functions raise such a
#' reply as an `rlmstudio_api_error`, and the message holds the server text.
#' [lms_chat_batch()] keeps the condition for that input and goes on to the
#' next input.
#'
#' To fit a longer prompt, load the model with a larger `context_length` in
#' [lms_load()]. The `max_context_length` column of
#' `list_models(detailed = TRUE)` gives the largest context length that the
#' model list reports for each model. If `context_length` is larger, the
#' server loads the model with the asked value and gives no message. On LM
#' Studio 0.4.25+1, it loaded google/gemma-3-1b at 65536 tokens, above its
#' maximum of 32768. So [lms_load()] gives a warning of class
#' `rlmstudio_context_above_max` that names both numbers, and then sends the
#' load. The `rlmstudio.quiet` option does not hide it. The warning needs the
#' model list, so it comes only with `force = FALSE`, and only when the list
#' has a maximum for the model and the model is not loaded yet.
#'
#' On LM Studio 0.4.25+1, the load endpoint answered a `rope_frequency_scale`
#' field in `...` with status 400 and the code `"unrecognized_keys"`. So
#' [lms_load()] cannot set RoPE scaling through that field. RoPE scaling
#' stretches the position encoding of a model past its trained length.
#'
#' To see how many tokens a prompt took, use
#' `lms_chat_batch(format = "data.frame")`. Its `input_tokens` column holds
#' the prompt token count that the server reports for each reply, on every
#' route.
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
  ...,
  token = NULL
) {
  model <- rlm_check_id(model, "model")
  rlm_check_flag(flash_attention, "flash_attention", null_ok = TRUE)
  rlm_check_flag(
    offload_kv_cache_to_gpu,
    "offload_kv_cache_to_gpu",
    null_ok = TRUE
  )
  rlm_check_flag(echo_load_config, "echo_load_config")
  rlm_check_flag(force, "force")

  stop_if_no_server(host)

  # Check if the model is already loaded to prevent redundant API calls. The
  # list holds every model, so the check below can also read the maximum
  # context length of a model that is not loaded yet.
  if (!isTRUE(force)) {
    models <- list_models(
      loaded = FALSE,
      detailed = TRUE,
      quiet = TRUE,
      host = host,
      token = token
    )
    loaded_keys <- if (nrow(models) > 0) {
      models$key[models$state == "loaded"]
    } else {
      character()
    }

    if (model %in% loaded_keys) {
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

    warn_context_above_max(context_length, model, models)
  }

  # 1. Build the explicit body based on current known parameters. `isTRUE()`
  # sends each of the two load settings as a plain `true` or `false`, with no
  # names or dims.
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
      isTRUE(flash_attention)
    } else {
      NULL
    },
    num_experts = if (!is.null(num_experts)) as.integer(num_experts) else NULL,
    offload_kv_cache_to_gpu = if (!is.null(offload_kv_cache_to_gpu)) {
      isTRUE(offload_kv_cache_to_gpu)
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

  req <- lms_client(host, token = token) |>
    httr2::req_url_path("api/v1/models/load") |>
    rlm_req_body(body) |>
    httr2::req_error(is_error = \(resp) FALSE)
  resp <- httr2::req_perform(req)

  if (httr2::resp_status(resp) == 200) {
    resp_data <- parse_ok_body(resp, "API Load Failed")
    fault <- load_reply_fault(resp_data, echo_load_config)
    if (!is.null(fault)) {
      rlm_abort_bad_reply(resp, "API Load Failed", fault, "a load reply")
    }
    if (isTRUE(echo_load_config)) {
      return(invisible(resp_data[["load_config"]]))
    }
    return(invisible(model))
  }

  rlm_abort_api(resp, "API Load Failed", request_sends_token(req))
}

#' Warn when a load asks for more context than the model list allows
#'
#' LM Studio loads a `context_length` above the `max_context_length` of the
#' model list as asked, with no clamp and no message (observed on 0.4.25+1).
#' This warning is the only sign in R. It shows past `quiet` and the
#' `rlmstudio.quiet` option. A value that `as.integer()` cannot read as one
#' number, a model with no row in the list, and a row with no maximum give no
#' warning.
#'
#' @param context_length The `context_length` argument of `lms_load()`.
#' @param model Character. The checked model name.
#' @param models The data frame that `list_models(detailed = TRUE)` returns.
#' @return `NULL`, invisibly.
#'
#' @noRd
warn_context_above_max <- function(context_length, model, models) {
  if (is.null(context_length) || !"max_context_length" %in% names(models)) {
    return(invisible(NULL))
  }
  # The body is built from the same `as.integer()` call later, so a value it
  # cannot read raises there as before, and its coercion warning shows once.
  asked <- tryCatch(
    suppressWarnings(as.integer(context_length)),
    error = function(e) NULL
  )
  if (length(asked) != 1L || is.na(asked)) {
    return(invisible(NULL))
  }
  row <- match(model, models$key)
  if (is.na(row)) {
    return(invisible(NULL))
  }
  max <- models$max_context_length[[row]]
  if (!is.numeric(max) || is.na(max) || asked <= max) {
    return(invisible(NULL))
  }

  max_text <- format(max, scientific = FALSE, trim = TRUE)
  cli::cli_warn(
    c(
      "{.arg context_length} {asked} is larger than {max_text}, the maximum context length that the model list gives for {.val {model}}.",
      "i" = "LM Studio loads the model with {asked} tokens and gives no message. Replies past the maximum can lose quality."
    ),
    class = "rlmstudio_context_above_max"
  )
  invisible(NULL)
}

#' Find the first way a load reply breaks its shape rules
#'
#' The body is a JSON object whose `status` is the string `"loaded"`, the one
#' load status the LM Studio docs list. With `echo_load_config = TRUE`, its
#' `load_config` is also a JSON object. Fields are read by exact name
#' (D-017).
#'
#' @param body The body, parsed with `simplifyVector = FALSE`.
#' @param echo_load_config Logical. Whether the caller reads `load_config`.
#' @return `NULL` when the body passes, or one clause naming the fault.
#'
#' @noRd
load_reply_fault <- function(body, echo_load_config) {
  if (!is_json_object(body)) {
    return("the response body is not a JSON object.")
  }
  if (!identical(body[["status"]], "loaded")) {
    return("`status` is not the string \"loaded\".")
  }
  if (isTRUE(echo_load_config) && !is_json_object(body[["load_config"]])) {
    return("`load_config` is not a JSON object.")
  }
  NULL
}
