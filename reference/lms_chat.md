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
  schema = NULL,
  token = NULL
)
```

## Arguments

- model:

  Character. The name of the loaded model. Must be one name, given as a
  single string.

- input:

  Character. The user prompt to send to the model. A character vector
  must hold no missing values.

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

- schema:

  A JSON Schema that the reply must match, or `NULL`. It needs
  `api_type = "openai"`, and any other `api_type` aborts before the
  request. See
  [`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
  for its form and for what is returned.

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

Depending on the arguments provided:

- If `simplify = FALSE`, returns a parsed list of the raw JSON response.

- If `simplify = TRUE` and `logprobs = FALSE`, returns a single
  character string containing the model's text response. With a
  `schema`, it returns the reply parsed into an R value instead.

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
With `simplify = TRUE`, it can raise `rlmstudio_bad_response` through
any of the three, for a reply that holds no readable answer text.

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

[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
checks the server once before its first input, and `lms_chat()` checks
it again for each input. If that check finds the server gone during the
batch, the batch aborts with `rlmstudio_no_server`, and no request goes
out after that. The condition then carries a `results` field, a list as
long as `inputs`. Its elements before the lost input hold the values
that `format = "list"` returns for those inputs. The element of the lost
input and every element after it are `NULL`. The check before the first
input adds no `results` field. A connection that fails after the check
passes, such as a server that stops during a request, raises an
`httr2_failure` error instead. That error aborts the batch and carries
no `results` field.

## API failure

A condition of class `rlmstudio_api_error` is raised when a REST call
returns a response that the wrapper treats as a failure. The condition
carries a `status` field, which holds the HTTP response status as an
integer.

[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
does not abort on it. The element of the failed input holds the
condition, or `NA` where the result is text, and the batch warns once
and goes on. See the details of
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md).

## Malformed response

A condition of class `rlmstudio_bad_response` is raised when the server
answers with a status the wrapper accepts and a body the wrapper cannot
read. It is raised where a wrapper checks the body before it reshapes
it, rather than indexing straight into whatever arrived. Four functions
raise it.

[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
raises it on an embeddings block it cannot trust. The vectors it returns
are placed by the index that the response reports, so a block with a
missing, repeated, or out-of-range index would otherwise pair a vector
with the wrong text and give back a matrix that is silently wrong.

[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md)
and
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
raise it with `simplify = TRUE` when the reply holds no readable answer
text. Both read the answer from the items of type `"message"` in the
`output` array. They raise it when `output` is missing, empty, or not an
array, or when an item in it is not a JSON object. They also raise it
when no item has the type `"message"`, as in a reply that holds only
reasoning or a tool call. The text of a message must be one string. For
[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md)
that is the `content` of the item. For
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
it is the `text` of each part of type `"output_text"`. For
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
only, the `content` of each message must be an array of JSON objects,
and the messages together must hold at least one `"output_text"` part.

[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
raises it in three cases, all only with `simplify = TRUE`. The first
case is a response whose `choices` field is missing, empty, or not an
array, or whose first element is not a JSON object with a `message`
object in it, so there is no reply to read. This case is raised with or
without a `schema`, and with `logprobs = TRUE` as well. The second case
is a reply that does not parse. A `schema` was given,
`logprobs = FALSE`, and the reply content is not one string of valid
JSON. The third case is reply content that is not one string, such as
`null`, a missing `content` field, a number, or an array. A reply that
holds only a tool call has `null` content. This case is raised without a
`schema`, and with `logprobs = TRUE` with or without one. In the second
and third cases, if the server reports the finish reason `"length"`, the
token limit cut the reply off. The message then says so and names
`max_tokens`. `lms_chat()` can raise the condition through all three
chat functions.

[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
does not abort on it. The element of the failed input holds the
condition, or `NA` where the result is text, and the batch warns once
and goes on. See the details of
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md).

The condition carries a `status` field, which holds the HTTP response
status as an integer. Today the status is always 200: each of these
functions reads the body only after a 200, and reports every other
status as an `rlmstudio_api_error` instead. A condition from
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
also carries two more fields. The `content` field holds the reply
content, and the `finish_reason` field holds the finish reason of the
first choice. Both are `NULL` for a response with no `choices`. In the
third case, `content` holds the value that was read, which is `NULL` for
`null` or missing content. For the second and third cases, the message
names the `content` field, so you can read what the model wrote without
a second request. The other messages name `simplify = FALSE`, which
returns the body unchanged, with one exception. An embeddings body that
did not parse at all is checked before that argument is read, so its
message points at the host instead.
