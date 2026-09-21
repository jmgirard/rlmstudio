# Turn Text into Embedding Vectors

Sends one or more texts to an embedding model and returns the vector
that the model produced for each one. The whole input vector travels in
a single request.

## Usage

``` r
lms_embed(
  model,
  input,
  host = "http://localhost:1234",
  simplify = TRUE,
  ...,
  token = NULL
)
```

## Arguments

- model:

  Character. The loaded embedding model name. Must be one name, given as
  a single string.

- input:

  Character. The texts to embed. A vector of length `n` returns `n`
  embeddings, in the order given. Must hold at least one value and no
  missing values.

- host:

  Character. Server URL.

- simplify:

  Logical. If `TRUE`, the default, returns a numeric matrix with one row
  per input. Any other value returns the parsed response body unchanged.

- ...:

  Additional fields for the request body. LM Studio ignores a field it
  does not recognize, and two OpenAI fields are worth naming for that
  reason: LM Studio ignores `dimensions`, so asking for a narrower
  vector has no effect. `encoding_format = "base64"` is untested against
  LM Studio: a server that honors it returns embeddings this function
  cannot read, and the default `simplify = TRUE` path then aborts.

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

If `simplify = FALSE`, a list representing the raw JSON response.
Otherwise, a double matrix with one row per input text and one column
per embedding dimension. The row at position `i` holds the embedding
that the response reported for the input at position `i`. The matrix
carries no row or column names.

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

`lms_embed()` raises it on an embeddings block it cannot trust. The
vectors it returns are placed by the index that the response reports, so
a block with a missing, repeated, or out-of-range index would otherwise
pair a vector with the wrong text and give back a matrix that is
silently wrong.

[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
raises it when a `schema` was given and the reply content is not one
string of valid JSON. It is raised only with `simplify = TRUE` and
`logprobs = FALSE`, which are the two settings under which the reply is
parsed.
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
and
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
can raise it through
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md).

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
vectors <- lms_embed(
  model = "text-embedding-nomic-embed-text-v1.5",
  input = c("the first document", "the second document")
)
dim(vectors)
} # }
```
