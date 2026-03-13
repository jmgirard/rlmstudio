#' Create a base request for the LM Studio API
#'
#' @param host Character. The host address of the local server. Defaults to "http://localhost:1234".
#'
#' @return An httr2 request object.
#' @noRd
lms_client <- function(host = "http://localhost:1234") {
  httr2::request(host) |>
    httr2::req_headers(
      "Content-Type" = "application/json",
      "Accept" = "application/json"
    )
}

#' Advanced Chat Completions via REST API
#'
#' Provides full control over the Chat Completions API, including system
#' prompts, multiple messages, and inference parameters.
#'
#' @param model Character. Unique identifier of the loaded model to use.
#' @param input Character. The user message or prompt.
#' @param system_prompt Character. Optional system instructions to guide model behavior.
#' @param host Character. The host address of the local server. Defaults to "http://localhost:1234".
#' @param api_type Character. Which REST API to use. \code{"native"} (default) uses LM Studio's
#'   proprietary \code{/api/v1/chat} endpoint for advanced features like stateful
#'   conversations and MCPs. \code{"openai"} uses the standard \code{/v1/chat/completions} endpoint.
#' @param simplify Logical. If \code{TRUE} (default), returns only the character string of the response.
#'   If \code{FALSE}, returns the full raw API response list.
#' @param ... Additional inference parameters passed to the API request body.
#'
#' @return A character string (if \code{simplify = TRUE}) or a list containing the full API response.
#' @export
lms_chat_advanced <- function(
  model,
  input,
  system_prompt = NULL,
  host = "http://localhost:1234",
  api_type = c("native", "openai"),
  simplify = TRUE,
  ...
) {
  if (!is_server_running()) {
    cli::cli_alert_danger(
      "The LM Studio server is not running. Run {.fn lms_server_start} first."
    )
    return(invisible(NULL))
  }

  api_type <- match.arg(api_type)

  # 1. Build the body and select the endpoint based on API type
  if (api_type == "native") {
    endpoint_path <- "api/v1/chat"

    body <- list(
      model = model,
      input = input,
      system_prompt = system_prompt
    )

    body <- Filter(Negate(is.null), body)
  } else {
    endpoint_path <- "v1/chat/completions"

    messages <- list()
    if (!is.null(system_prompt)) {
      messages[[length(messages) + 1]] <- list(
        role = "system",
        content = system_prompt
      )
    }
    messages[[length(messages) + 1]] <- list(role = "user", content = input)

    body <- list(
      model = model,
      messages = messages
    )
  }

  # 2. Merge dots into the body
  body <- utils::modifyList(body, list(...))

  # 3. Use the centralized httr2 client
  resp <- lms_client(host) |>
    httr2::req_url_path(endpoint_path) |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  # 4. Handle Response
  if (httr2::resp_status(resp) == 200) {
    resp_data <- httr2::resp_body_json(resp)

    if (isTRUE(simplify)) {
      if (api_type == "native") {
        # Extract text from native LM Studio response
        return(resp_data$output[[1]]$content)
      } else {
        # Extract text from standard OpenAI response
        return(resp_data$choices[[1]]$message$content)
      }
    } else {
      return(resp_data)
    }
  }

  # 5. Robust error message extraction
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

  cli::cli_abort(c("x" = "Chat Completion Failed: {err_msg}"))
}

#' Basic Chat Completion via REST API
#'
#' A simplified wrapper for quick interactions with a loaded model.
#'
#' @inheritParams lms_chat_advanced
#' @export
lms_chat <- function(model, input, ...) {
  lms_chat_advanced(model = model, input = input, ...)
}

#' Batch Chat Completions via REST API
#'
#' Applies chat completions to a vector of input strings. This is useful for
#' processing multiple documents or prompts in a single call, such as during
#' zero-shot classification or text extraction.
#'
#' @inheritParams lms_chat_advanced
#' @param inputs Character vector. The user messages or prompts to process.
#' @param format Character. The desired output format: \code{"vector"} (default),
#'   \code{"list"}, or \code{"data.frame"}.
#'
#' @return A character vector, list, or data frame depending on the \code{format}
#'   argument and the value of \code{simplify}.
#' @export
lms_chat_batch <- function(
  model,
  inputs,
  system_prompt = NULL,
  format = c("vector", "list", "data.frame"),
  host = "http://localhost:1234",
  simplify = TRUE,
  ...
) {
  if (!is_server_running()) {
    cli::cli_alert_danger(
      "The LM Studio server is not running. Run {.fn lms_server_start} first."
    )
    return(invisible(NULL))
  }

  format <- match.arg(format)

  if (!is.character(inputs) || length(inputs) == 0) {
    cli::cli_abort("{.arg inputs} must be a non-empty character vector.")
  }

  n_inputs <- length(inputs)

  # Capture ID to ensure update() can find it across environments
  pb <- cli::cli_progress_bar(
    name = "Batch processing",
    total = n_inputs,
    format = "{cli::pb_name} {cli::pb_bar} {cli::pb_percent} | ETA: {cli::pb_eta}"
  )
  on.exit(cli::cli_progress_done(id = pb), add = TRUE)

  results <- lapply(inputs, function(input) {
    res <- lms_chat_advanced(
      model = model,
      input = input,
      system_prompt = system_prompt,
      host = host,
      simplify = simplify,
      ...
    )
    # Explicitly use ID for robustness
    cli::cli_progress_update(id = pb)
    res
  })

  if (format == "data.frame") {
    if (!isTRUE(simplify)) {
      cli::cli_abort(
        "The {.val data.frame} format requires {.code simplify = TRUE}."
      )
    }
    return(data.frame(
      input = inputs,
      output = unlist(results),
      stringsAsFactors = FALSE
    ))
  }

  if (format == "vector") {
    if (!isTRUE(simplify)) {
      cli::cli_warn(
        "The {.val vector} format is not compatible with {.code simplify = FALSE}. Returning a list."
      )
      return(results)
    }
    return(unlist(results))
  }

  results
}
