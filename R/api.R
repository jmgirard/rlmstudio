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
#' @param prompt Character. A single user prompt to send to the model.
#' @param system_prompt Character. An optional system prompt to set model behavior.
#' @param messages A list of message lists representing the conversation history.
#'   If provided, this overrides \code{prompt} and \code{system_prompt}.
#' @param model Character. The identifier of the loaded model to use.
#'   LM Studio often ignores this if only one model is loaded.
#' @param temperature Numeric. The temperature for sampling (default 0.7).
#' @param max_tokens Integer. The maximum number of tokens to generate (default -1 for infinite).
#' @param simplify Logical. If \code{TRUE}, returns only the character string of
#'   the model's response. If \code{FALSE}, returns the full parsed list.
#' @param base_url Character. The base URL of the local server.
#'
#' @return A character string if \code{simplify = TRUE}, otherwise a parsed
#'   list containing the full API response.
#' @export
api_chat_completions <- function(prompt = NULL,
                                 system_prompt = NULL,
                                 messages = NULL,
                                 model = "local-model",
                                 temperature = 0.7,
                                 max_tokens = -1,
                                 simplify = FALSE,
                                 base_url = "http://localhost:1234/v1") {

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

  # Parse the JSON response
  out <- httr2::resp_body_json(resp)

  if (isTRUE(simplify)) {
    return(out$choices[[1]]$message$content)
  }

  out
}

#' Quick chat via the API
#'
#' A convenience wrapper around \code{api_chat_completions} for simple, one-turn interactions.
#'
#' @param prompt Character. The prompt to send to the model.
#' @param system_prompt Character. An optional system prompt.
#' @param simplify Logical. Whether to return only the response text (default)
#'   or the full API response list.
#' @param ... Additional arguments passed to \code{api_chat_completions}.
#'
#' @return A character string if \code{simplify = TRUE}, or the full response list otherwise.
#' @export
api_chat <- function(prompt, system_prompt = NULL, simplify = TRUE, ...) {
  api_chat_completions(
    prompt = prompt,
    system_prompt = system_prompt,
    simplify = simplify,
    ...
  )
}
