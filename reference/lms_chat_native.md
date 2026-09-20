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
  ...,
  token = NULL
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

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

If `simplify = FALSE`, returns a list representing the raw JSON
response. If `simplify = TRUE`, returns a character string containing
the model's text output.

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
