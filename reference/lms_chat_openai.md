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

## Value

If `simplify = FALSE`, returns a list representing the raw JSON
response. Otherwise, returns a character string containing the generated
text. If `logprobs = TRUE`, it returns an `lms_chat_result` object with
the log probabilities populated as `NULL` since they are currently
stubbed in the LM Studio OpenAI endpoint.

## Server not running

Functions that call the LM Studio REST API check that a server answers
at the `host` address. A condition of class `rlmstudio_no_server` is
raised when the LM Studio server is not running. Start the server with
[`lms_server_start()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_start.md),
or give `host` the address that your server listens on.

## API failure

A condition of class `rlmstudio_api_error` is raised when a REST call
returns a response that the wrapper treats as a failure. The condition
carries a `status` field, which holds the HTTP response status as an
integer.
