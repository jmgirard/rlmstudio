# Batch Chat Completion with LM Studio

Process a vector of inputs sequentially through LM Studio.

## Usage

``` r
lms_chat_batch(
  model,
  inputs,
  system_prompt = NULL,
  format = c("vector", "list", "data.frame"),
  host = "http://localhost:1234",
  simplify = TRUE,
  quiet = FALSE,
  ...,
  token = NULL
)
```

## Arguments

- model:

  Character. The loaded model name. Must be one name, given as a single
  string.

- inputs:

  Character vector. The prompts to process. Must hold at least one value
  and no missing values.

- system_prompt:

  Character. Optional system prompt.

- format:

  Character. Output format: "vector", "list", or "data.frame".

- host:

  Character. Server URL.

- simplify:

  Logical. If TRUE, parses outputs.

- quiet:

  Logical. Whether to suppress the progress bar.

- ...:

  Additional arguments passed to `lms_chat`.

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

The return type depends on the `format` argument:

- `"vector"`: A character vector of responses. This format is only
  supported if `simplify = TRUE` and `logprobs = FALSE`.

- `"list"`: A list where each element is the response corresponding to
  the provided input.

- `"data.frame"`: A data.frame containing `input` and `output` columns.
  If `logprobs = TRUE`, an additional list-column named `logprobs` is
  included.

## Details

This function calls
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
once for each element of `inputs`. It raises `rlmstudio_no_server`
itself, before the first call. It can raise `rlmstudio_api_error`
through
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md).

## Server not running

Functions that call the LM Studio REST API open a TCP connection to the
hostname and port named in `host` before they send the request. A
function that checks its own arguments does that first, so a bad
`model`, `job_id`, `input`, or `inputs` aborts with an argument message
and no condition class even when the server is down. A condition of
class `rlmstudio_no_server` is raised when that connection cannot be
opened. A refused connection raises it. So do an address the package
cannot parse and a hostname that does not resolve. An address that
neither accepts nor refuses the connection also raises it. That case
waits for the operating system to give up, which can take a minute.
Start the server with
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
