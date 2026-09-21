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

  Additional arguments passed to `lms_chat`, such as `api_type`,
  `logprobs`, or `schema`. A `schema` and the `api_type` it needs are
  checked before the first call.

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

The return type depends on the `format` argument:

- `"vector"`: A character vector of responses. This format is only
  supported if `simplify = TRUE` and `logprobs = FALSE`. With a
  `schema`, it warns and returns the list instead.

- `"list"`: A list where each element is the response corresponding to
  the provided input. With a `schema`, `simplify = TRUE`, and
  `logprobs = FALSE`, each element is the parsed reply.

- `"data.frame"`: A data.frame containing `input` and `output` columns.
  If `logprobs = TRUE`, an additional list-column named `logprobs` is
  included. With a `schema` and `logprobs = FALSE`, `output` is a
  list-column of parsed replies.

## Details

This function calls
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
once for each element of `inputs`. It raises `rlmstudio_no_server`
itself, before the first call. It can raise `rlmstudio_api_error`
through
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md).
With a `schema`, it can raise `rlmstudio_bad_response` through
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md).

## Server not running

Functions that call the LM Studio REST API open a TCP connection to the
hostname and port named in `host` before they send the request. A
function that checks its own arguments does that first, so a bad
`model`, `job_id`, `input`, `inputs`, or `schema` aborts with an
argument message and no condition class even when the server is down. A
condition of class `rlmstudio_no_server` is raised when that connection
cannot be opened. A refused connection raises it. So do an address the
package cannot parse and a hostname that does not resolve. An address
that neither accepts nor refuses the connection also raises it. That
case waits for the operating system to give up, which can take a minute.
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

## Malformed response

A condition of class `rlmstudio_bad_response` is raised when the server
answers with a status the wrapper accepts and a body the wrapper cannot
read. It is raised where a wrapper checks the body before it reshapes
it, rather than indexing straight into whatever arrived. Two functions
raise it.

[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
raises it on an embeddings block it cannot trust. The vectors it returns
are placed by the index that the response reports, so a block with a
missing, repeated, or out-of-range index would otherwise pair a vector
with the wrong text and give back a matrix that is silently wrong.

[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
raises it when a `schema` was given and the reply content is not one
string of valid JSON. It is raised only with `simplify = TRUE` and
`logprobs = FALSE`, which are the two settings under which the reply is
parsed.
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
and `lms_chat_batch()` can raise it through
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md).

The condition carries a `status` field, which holds the HTTP response
status as an integer. Today the status is always 200: both functions
read the body only after a 200, and report every other status as an
`rlmstudio_api_error` instead. The message names the argument that
returns the body unchanged, so you can read what arrived. The one
exception is an embeddings body that did not parse at all: that check
runs before the argument is read, so its message points at the host
instead.
