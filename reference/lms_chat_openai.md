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
  ...,
  schema = NULL,
  token = NULL
)
```

## Arguments

- model:

  Character. The loaded model name. Must be one name, given as a single
  string.

- messages:

  List. A structured list of role and content pairs.

- host:

  Character. Server URL.

- logprobs:

  Logical. Whether to request logprobs (currently stubbed by LM Studio).

- simplify:

  Logical. If TRUE, parses output to text.

- ...:

  Additional API arguments. A `response_format` here cannot be combined
  with `schema`.

- schema:

  A JSON Schema, written as a named list, that the reply must match, or
  `NULL` for a free text reply. It is sent as the `schema` field of a
  `response_format` of type `"json_schema"`, with the name `"response"`
  and `strict` set to `true`. A JSON array of one item must be written
  as a list, such as `required = list("score")`, or wrapped in
  [`I()`](https://rdrr.io/r/base/AsIs.html). A plain vector of length
  one is sent as a single value, not as an array. The package checks
  only that `schema` is a named list, an empty list, or `NULL`. The
  server checks the schema itself.

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

If `simplify = FALSE`, returns a list representing the raw JSON
response. Otherwise, returns a character string containing the generated
text. If `logprobs = TRUE`, it returns an `lms_chat_result` object with
the log probabilities populated as `NULL` since they are currently
stubbed in the LM Studio OpenAI endpoint.

With a `schema`, `simplify = TRUE`, and `logprobs = FALSE`, the reply is
parsed with `jsonlite::parse_json(simplifyVector = TRUE)` and the parsed
value is returned. A JSON object becomes a named list, and an array of
numbers becomes a vector. With `simplify = FALSE` or `logprobs = TRUE`,
the reply stays a string.

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

`lms_chat_openai()` raises it when a `schema` was given and the reply
content is not one string of valid JSON. It is raised only with
`simplify = TRUE` and `logprobs = FALSE`, which are the two settings
under which the reply is parsed.
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
and
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
can raise it through `lms_chat_openai()`.

The condition carries a `status` field, which holds the HTTP response
status as an integer. Today the status is always 200: both functions
read the body only after a 200, and report every other status as an
`rlmstudio_api_error` instead. The message names the argument that
returns the body unchanged, so you can read what arrived. The one
exception is an embeddings body that did not parse at all: that check
runs before the argument is read, so its message points at the host
instead.

## Examples

``` r
if (FALSE) { # \dontrun{
lms_chat_openai(
  model = "google/gemma-3-1b",
  messages = list(
    list(role = "user", content = "Rate 'Great value.' from 1 to 5.")
  ),
  schema = list(
    type = "object",
    properties = list(score = list(type = "integer")),
    required = list("score")
  )
)
} # }
```
