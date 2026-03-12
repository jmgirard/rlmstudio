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
#' @param messages A list of message lists representing the conversation history.
#' @param model Character. The identifier of the loaded model to use.
#'   LM Studio often ignores this if only one model is loaded.
#' @param temperature Numeric. The temperature for sampling (default 0.7).
#' @param max_tokens Integer. The maximum number of tokens to generate (default -1 for infinite).
#' @param base_url Character. The base URL of the local server.
#'
#' @return A parsed list containing the API response.
#' @export
#'
#' @examples
#' \dontrun{
#' msgs <- list(list(role = "user", content = "What is the capital of France?"))
#' response <- api_chat_completions(msgs)
#' cat(response$choices[[1]]$message$content)
#' }
api_chat_completions <- function(messages,
                                 model = "local-model",
                                 temperature = 0.7,
                                 max_tokens = -1,
                                 base_url = "http://localhost:1234/v1") {

  # Build the payload
  body <- list(
    model = model,
    messages = messages,
    temperature = temperature,
    max_tokens = max_tokens,
    stream = FALSE
  )

  # Prepare and perform the request
  resp <- lms_client(base_url) |>
    httr2::req_url_path_append("chat/completions") |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = function(resp) httr2::resp_status(resp) >= 400) |>
    httr2::req_perform()

  # Return the parsed JSON response
  httr2::resp_body_json(resp)
}

#' Quick chat via the API
#'
#' A convenience wrapper around `api_chat_completions` for simple, one-turn interactions.
#'
#' @param prompt Character. The prompt to send to the model.
#' @param system_prompt Character. An optional system prompt.
#' @param ... Additional arguments passed to `api_chat_completions`.
#'
#' @return A character string of the model's response text.
#' @export
api_chat <- function(prompt, system_prompt = NULL, ...) {

  messages <- list()

  if (!is.null(system_prompt)) {
    messages <- append(messages, list(list(role = "system", content = system_prompt)))
  }

  messages <- append(messages, list(list(role = "user", content = prompt)))

  resp <- api_chat_completions(messages = messages, ...)

  resp$choices[[1]]$message$content
}
