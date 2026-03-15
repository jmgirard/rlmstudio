# Chat Completion via OpenAI Compatibility API

Direct interface to LM Studio's OpenAI-compatible endpoint. Uses the
messages array format.

## Usage

``` r
lms_chat_openai(
  model,
  messages,
  host = "http://localhost:1234",
  logprobs = FALSE,
  simplify = TRUE,
  ...
)
```

## Arguments

- model:

  Character. The loaded model name.

- messages:

  List. A structured list of role and content pairs.

- host:

  Character. Server URL.

- logprobs:

  Logical. Whether to request logprobs (currently stubbed by LM Studio).

- simplify:

  Logical. If TRUE, parses output to text.

- ...:

  Additional API arguments.
