# Batch Chat Completions via REST API

Applies chat completions to a vector of input strings. This is useful
for processing multiple documents or prompts in a single call, such as
during zero-shot classification or text extraction.

## Usage

``` r
lms_chat_batch(
  model,
  inputs,
  system_prompt = NULL,
  format = c("vector", "list", "data.frame"),
  host = "http://localhost:1234",
  simplify = TRUE,
  ...
)
```

## Arguments

- model:

  Character. Unique identifier of the loaded model to use.

- inputs:

  Character vector. The user messages or prompts to process.

- system_prompt:

  Character. Optional system instructions to guide model behavior.

- format:

  Character. The desired output format: `"vector"` (default), `"list"`,
  or `"data.frame"`.

- host:

  Character. The host address of the local server. Defaults to
  "http://localhost:1234".

- simplify:

  Logical. If `TRUE` (default), returns only the character string of the
  response. If `FALSE`, returns the full raw API response list.

- ...:

  Additional inference parameters passed to the API request body.

## Value

A character vector, list, or data frame depending on the `format`
argument and the value of `simplify`.

## See also

- [LM Studio Native Chat
  API](https://lmstudio.ai/docs/developer/rest/chat)

- [OpenAI Compatible Chat
  API](https://lmstudio.ai/docs/developer/openai-compat/chat-completions)
