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

#' Send an advanced chat request to the LM Studio API
#'
#' Provides a direct interface to the \code{/api/v1/chat} endpoint, supporting
#' LM Studio specific features like MCP integrations and reasoning settings.
#'
#' @param model Character. The identifier of the loaded model to use.
#' @param input Character or List. The user message or a list of message objects.
#' @param system_prompt Character. An optional system prompt to set model behavior.
#' @param integrations List. A list of integrations (e.g., MCP servers) to enable.
#' @param stream Logical. Whether to stream partial outputs via SSE.
#' @param temperature Numeric. Randomness in token selection (0 to 1).
#' @param top_p Numeric. Minimum cumulative probability for possible next tokens.
#' @param top_k Integer. Limits next token selection to top-k probable tokens.
#' @param min_p Numeric. Minimum base probability for a token.
#' @param repeat_penalty Numeric. Penalty for repeating token sequences.
#' @param max_output_tokens Integer. Maximum number of tokens to generate.
#' @param reasoning Character. Reasoning setting: "off", "low", "medium", "high", or "on".
#' @param context_length Integer. Number of tokens to consider as context.
#' @param store Logical. Whether to store the chat.
#' @param previous_response_id Character. ID of a previous response to continue a conversation.
#' @param simplify Logical. If \code{TRUE}, returns the response text with metadata
#'   as attributes. If \code{FALSE}, returns the full parsed list.
#' @param host Character. The host address of the local server.
#'
#' @return A character string (with attributes) if \code{simplify = TRUE},
#'   otherwise a parsed list.
#' @export
lms_chat_advanced <- function(model,
                              input,
                              system_prompt = NULL,
                              integrations = NULL,
                              stream = FALSE,
                              temperature = NULL,
                              top_p = NULL,
                              top_k = NULL,
                              min_p = NULL,
                              repeat_penalty = NULL,
                              max_output_tokens = NULL,
                              reasoning = NULL,
                              context_length = NULL,
                              store = NULL,
                              previous_response_id = NULL,
                              simplify = FALSE,
                              host = "http://localhost:1234") {

  if (!is_server_running()) {
    cli::cli_abort("The LM Studio server is not running. Run {.fn start_server} first.")
  }

  body <- list(
    model = model,
    input = input,
    system_prompt = system_prompt,
    integrations = integrations,
    stream = stream,
    temperature = temperature,
    top_p = top_p,
    top_k = if (!is.null(top_k)) as.integer(top_k) else NULL,
    min_p = min_p,
    repeat_penalty = repeat_penalty,
    max_output_tokens = if (!is.null(max_output_tokens)) as.integer(max_output_tokens) else NULL,
    reasoning = reasoning,
    context_length = if (!is.null(context_length)) as.integer(context_length) else NULL,
    store = store,
    previous_response_id = previous_response_id
  )

  # Remove NULLs to let the API use its defaults
  body <- Filter(Negate(is.null), body)

  resp <- lms_client(host) |>
    httr2::req_url_path_append("api/v1/chat") |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) httr2::resp_status(resp) >= 400) |>
    httr2::req_perform()

  out <- httr2::resp_body_json(resp)

  if (isTRUE(simplify)) {
    if (is.null(out$output) || length(out$output) == 0) return(NULL)

    # Extract all message content
    content_list <- lapply(out$output, function(x) {
      if (identical(x$type, "message")) return(x$content)
      return(NULL)
    })

    content <- paste(unlist(Filter(Negate(is.null), content_list)), collapse = "\n")

    # Attach comprehensive metadata as attributes
    attr(content, "model_instance_id") <- out$model_instance_id
    attr(content, "response_id") <- out$response_id
    attr(content, "stats") <- out$stats

    # Check if there are tool calls to attach
    tool_calls <- Filter(function(x) identical(x$type, "tool_call"), out$output)
    if (length(tool_calls) > 0) {
      attr(content, "tool_calls") <- tool_calls
    }

    return(content)
  }

  out
}

#' Quick chat via the API
#'
#' A convenience wrapper around \code{lms_chat_advanced} for simple interactions.
#'
#' @param model Character. The identifier of the loaded model to use.
#' @param input Character. The prompt or message to send.
#' @param system_prompt Character. An optional system prompt.
#' @param simplify Logical. Whether to return response text (default) or the full list.
#' @param host Character. The host address of the local server.
#' @param ... Additional arguments passed to \code{lms_chat_advanced}.
#'
#' @return Response text or a full list.
#' @export
lms_chat <- function(model, input, system_prompt = NULL, simplify = TRUE, host = "http://localhost:1234", ...) {
  lms_chat_advanced(
    model = model,
    input = input,
    system_prompt = system_prompt,
    simplify = simplify,
    host = host,
    ...
  )
}
