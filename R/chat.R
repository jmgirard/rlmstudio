#' Create a base request for the LM Studio API
#'
#' @param base_url Character. The base URL of the local server.
#'   Defaults to "http://localhost:1234/v1".
#'
#' @return An httr2 request object.
#' @export
lms_client <- function(base_url = "http://localhost:1234/v1") {
  httr2::request(base_url) |>
    httr2::req_headers(
      "Content-Type" = "application/json",
      "Accept" = "application/json"
    )
}

#' Send a chat completion request to the LM Studio API
#'
#' Provides a direct interface to the \code{/chat/completions} endpoint, supporting
#' all OpenAI-compatible parameters.
#'
#' @param prompt Character. A single user prompt.
#' @param system_prompt Character. An optional system prompt to set model behavior.
#' @param messages A list of message lists representing the conversation history.
#'   If provided, this overrides \code{prompt} and \code{system_prompt}.
#' @param model Character. The identifier of the loaded model to use.
#' @param frequency_penalty Numeric. Number between -2.0 and 2.0. Positive values
#'   penalize new tokens based on their existing frequency in the text.
#' @param logit_bias Map. Modify the likelihood of specified tokens appearing.
#' @param logprobs Logical. Whether to return log probabilities of output tokens.
#' @param top_logprobs Integer. Number of most likely tokens to return at each position.
#' @param max_tokens Integer. The maximum number of tokens to generate.
#' @param n Integer. How many chat completion choices to generate for each input.
#' @param presence_penalty Numeric. Number between -2.0 and 2.0. Positive values
#'   penalize new tokens based on whether they have appeared yet.
#' @param response_format List. Use \code{list(type = "json_object")} for JSON mode.
#' @param seed Integer. If specified, the system will sample deterministically.
#' @param stop Character vector. Up to 4 sequences where the API will stop.
#' @param stream Logical. If \code{TRUE}, partial message deltas will be sent.
#' @param temperature Numeric. Sampling temperature between 0 and 2.
#' @param top_p Numeric. Nucleus sampling alternative to temperature.
#' @param tools List. A list of tools (functions) the model may call.
#' @param tool_choice Character or List. Controls which tool is called.
#' @param user Character. A unique identifier representing your end-user.
#' @param simplify Logical. If \code{TRUE}, returns the response text with metadata
#'   as attributes. If \code{FALSE}, returns the full parsed list.
#' @param base_url Character. The base URL of the local server.
#'
#' @return A character string (with attributes) if \code{simplify = TRUE},
#'   otherwise a parsed list.
#' @export
lms_prompt <- function(prompt = NULL,
                                 system_prompt = NULL,
                                 messages = NULL,
                                 model = "local-model",
                                 frequency_penalty = NULL,
                                 logit_bias = NULL,
                                 logprobs = NULL,
                                 top_logprobs = NULL,
                                 max_tokens = NULL,
                                 n = NULL,
                                 presence_penalty = NULL,
                                 response_format = NULL,
                                 seed = NULL,
                                 stop = NULL,
                                 stream = FALSE,
                                 temperature = 0.7,
                                 top_p = NULL,
                                 tools = NULL,
                                 tool_choice = NULL,
                                 user = NULL,
                                 simplify = FALSE,
                                 base_url = "http://localhost:1234/v1") {

  if (!is_server_running()) {
    cli::cli_abort("The LM Studio server is not running. Run {.fn server_start} first.")
  }

  # Build messages if not provided
  if (is.null(messages)) {
    if (is.null(prompt)) {
      cli::cli_abort("Either {.arg prompt} or {.arg messages} must be provided.")
    }
    messages <- list()
    if (!is.null(system_prompt)) {
      messages <- append(messages, list(list(role = "system", content = system_prompt)))
    }
    messages <- append(messages, list(list(role = "user", content = prompt)))
  }

  # Build the payload, excluding NULLs to let the API use its defaults
  body <- list(
    model = model,
    messages = messages,
    frequency_penalty = frequency_penalty,
    logit_bias = logit_bias,
    logprobs = logprobs,
    top_logprobs = top_logprobs,
    max_tokens = max_tokens,
    n = n,
    presence_penalty = presence_penalty,
    response_format = response_format,
    seed = seed,
    stop = stop,
    stream = stream,
    temperature = temperature,
    top_p = top_p,
    tools = tools,
    tool_choice = tool_choice,
    user = user
  )
  body <- Filter(Negate(is.null), body)

  # Perform the request using the native pipe
  resp <- lms_client(base_url) |>
    httr2::req_url_path_append("chat/completions") |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) httr2::resp_status(resp) >= 400) |>
    httr2::req_perform()

  out <- httr2::resp_body_json(resp)

  if (isTRUE(simplify)) {
    if (length(out$choices) == 0) return(NULL)

    # Extract the first choice content
    content <- out$choices[[1]]$message$content

    # Attach comprehensive metadata as attributes
    attr(content, "usage") <- out$usage
    attr(content, "model") <- out$model
    attr(content, "id") <- out$id
    attr(content, "finish_reason") <- out$choices[[1]]$finish_reason
    if (!is.null(out$choices[[1]]$message$tool_calls)) {
      attr(content, "tool_calls") <- out$choices[[1]]$message$tool_calls
    }

    return(content)
  }

  out
}

#' Quick chat via the API
#'
#' A convenience wrapper around \code{lms_prompt} for simple interactions.
#'
#' @param model Character. The identifier of the model to use.
#' @param prompt Character. The prompt to send.
#' @param system_prompt Character. An optional system prompt.
#' @param simplify Logical. Whether to return response text (default) or the list.
#' @param ... Additional arguments passed to \code{lms_prompt}.
#'
#' @return Response text or a full list.
#' @export
lms_chat <- function(model, prompt, system_prompt = NULL, simplify = TRUE, ...) {
  lms_prompt(
    prompt = prompt,
    system_prompt = system_prompt,
    model = model,
    simplify = simplify,
    ...
  )
}
