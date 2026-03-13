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
