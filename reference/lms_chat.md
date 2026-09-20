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
  ...,
  token = NULL
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

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

Depending on the arguments provided:

- If `simplify = FALSE`, returns a parsed list of the raw JSON response.

- If `simplify = TRUE` and `logprobs = FALSE`, returns a single
  character string containing the model's text response.

- If `simplify = TRUE` and `logprobs = TRUE` (and the chosen API type
  supports it), returns an object of class `lms_chat_result` containing
  both the text and a data.frame of token probabilities.

## Details

This function calls
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md),
or
[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md),
according to `api_type`. It runs no request of its own. It can raise
`rlmstudio_no_server` and `rlmstudio_api_error` through
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md),
or
[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md).

## Server not running

Functions that call the LM Studio REST API first open a TCP connection
to the hostname and port named in `host`. A condition of class
`rlmstudio_no_server` is raised when that connection cannot be opened. A
refused connection raises it. So do an address the package cannot parse
and a hostname that does not resolve. An address that neither accepts
nor refuses the connection also raises it. That case waits for the
operating system to give up, which can take a minute. Start the server
with
[`lms_server_start()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_start.md),
or give `host` the address that your server listens on.

The check reads the port and nothing else. Any process holding that port
accepts the connection, so the condition is not raised even though no LM
Studio server is there. The call then fails later, as an
`rlmstudio_api_error` or as a raw parse error, rather than as
`rlmstudio_no_server`. Use
[`lms_server_ready()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_ready.md)
for the stronger test: it asks the host for a model list and reports
`TRUE` only for an answer that an LM Studio server would give.

## API failure

A condition of class `rlmstudio_api_error` is raised when a REST call
returns a response that the wrapper treats as a failure. The condition
carries a `status` field, which holds the HTTP response status as an
integer.
