# Chat Completion via OpenResponses API

Direct interface to LM Studio's OpenResponses endpoint. Supports
logprobs and custom instructions.

## Usage

``` r
lms_chat_openresponses(
  model,
  input,
  instructions = NULL,
  host = "http://localhost:1234",
  logprobs = FALSE,
  simplify = TRUE,
  ...
)
```

## Arguments

- model:

  Character. The loaded model name.

- input:

  Character. The user prompt.

- instructions:

  Character. Optional system instructions.

- host:

  Character. Server URL.

- logprobs:

  Logical. Whether to return token probabilities.

- simplify:

  Logical. If TRUE, parses output to text and dataframe. If FALSE,
  returns raw list.

- ...:

  Additional API arguments (e.g., top_logprobs, temperature).

## Value

If `simplify = FALSE`, returns a list representing the raw JSON
response. Otherwise, returns a character string containing the generated
text. If `logprobs = TRUE`, returns an object of class `lms_chat_result`
incorporating both the text and probability data.
