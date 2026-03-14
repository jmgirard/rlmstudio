# Chat Completions via REST API

Provides full control over the Chat Completions API, including system
prompts, multiple messages, and inference parameters.

## Usage

``` r
lms_chat(
  model,
  input,
  system_prompt = NULL,
  host = "http://localhost:1234",
  api_type = c("native", "openai"),
  simplify = TRUE,
  ...
)
```

## Arguments

- model:

  Character. Unique identifier of the loaded model to use.

- input:

  Character. The user message or prompt.

- system_prompt:

  Character. Optional system instructions to guide model behavior.

- host:

  Character. The host address of the local server. Defaults to
  "http://localhost:1234".

- api_type:

  Character. Which REST API to use. `"native"` (default) uses LM
  Studio's proprietary `/api/v1/chat` endpoint for advanced features
  like stateful conversations and MCPs. `"openai"` uses the standard
  `/v1/chat/completions` endpoint.

- simplify:

  Logical. If `TRUE` (default), returns only the character string of the
  response. If `FALSE`, returns the full raw API response list.

- ...:

  Additional inference parameters passed to the API request body.

## Value

A character string (if `simplify = TRUE`) or a list containing the full
API response.

## See also

- [LM Studio Native Chat
  API](https://lmstudio.ai/docs/developer/rest/chat)

- [OpenAI Compatible Chat
  API](https://lmstudio.ai/docs/developer/openai-compat/chat-completions)

## Examples

``` r
if (FALSE) { # \dontrun{
# Ensure the server is running and the model is loaded
lms_server_start()
lms_download("google/gemma-3-1b")
lms_load("google/gemma-3-1b")

# Basic chat with a loaded model
lms_chat(model = "google/gemma-3-1b", input = "What is the capital of France?")

# Chat with a system prompt and custom inference parameters
lms_chat(
  model = "google/gemma-3-1b",
  input = "Write a short poem about R.",
  system_prompt = "You are a helpful assistant.",
  temperature = 0.7
)
} # }
```
