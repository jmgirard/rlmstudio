# Chat Completion with LM Studio

Send a prompt to a locally running LM Studio model. This wrapper
automatically routes your request to the appropriate subfunction based
on the selected API type.

## Usage

``` r
lms_chat(
  model,
  input,
  system_prompt = NULL,
  host = "http://localhost:1234",
  api_type = c("openresponses", "openai", "native"),
  logprobs = FALSE,
  simplify = TRUE,
  ...
)
```

## Arguments

- model:

  Character. The name of the loaded model.

- input:

  Character. The user prompt to send to the model.

- system_prompt:

  Character. An optional system prompt to guide model behavior.

- host:

  Character. The base URL of the LM Studio server. Default is
  "http://localhost:1234".

- api_type:

  Character. The LM Studio API endpoint to use. Options are
  "openresponses" (default), "openai", or "native".

- logprobs:

  Logical. Whether to return the log probabilities of the generated
  tokens. Default is FALSE.

- simplify:

  Logical. If TRUE, extracts the core text response. Default is TRUE.

- ...:

  Additional arguments passed to the selected API body.

## Value

Depending on the arguments provided:

- If `simplify = FALSE`, returns a parsed list of the raw JSON response.

- If `simplify = TRUE` and `logprobs = FALSE`, returns a single
  character string containing the model's text response.

- If `simplify = TRUE` and `logprobs = TRUE` (and the chosen API type
  supports it), returns an object of class `lms_chat_result` containing
  both the text and a data.frame of token probabilities.
