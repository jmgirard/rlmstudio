# Chat Completion via Native API

Direct interface to LM Studio's v1 Native endpoint. Optimized for
stateful chats and hardware control.

## Usage

``` r
lms_chat_native(
  model,
  input,
  system_prompt = NULL,
  host = "http://localhost:1234",
  simplify = TRUE,
  ...
)
```

## Arguments

- model:

  Character. The loaded model name.

- input:

  Character. The user prompt.

- system_prompt:

  Character. Optional system prompt.

- host:

  Character. Server URL.

- simplify:

  Logical. If TRUE, parses output to text.

- ...:

  Additional API arguments.

## Value

If `simplify = FALSE`, returns a list representing the raw JSON
response. If `simplify = TRUE`, returns a character string containing
the model's text output.
