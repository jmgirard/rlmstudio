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
  one is sent as a single value, not as an array. An empty object nested
  in the schema, such as `properties`, is written
  `setNames(list(), character())`, because
  [`list()`](https://rdrr.io/r/base/list.html) is sent as the empty
  array `[]`. The package checks only that `schema` is a named list, an
  empty list, or `NULL`. The server checks the schema itself.

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
stubbed in the LM Studio OpenAI endpoint. With `simplify = TRUE`, reply
content that is not one string, such as the `null` content of a reply
that holds only a tool call, raises `rlmstudio_bad_response`.

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

[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
checks the server once before its first input, and
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
checks it again for each input. If that check finds the server gone
during the batch, the batch aborts with `rlmstudio_no_server`, and no
request goes out after that. The condition then carries a `results`
field, a list as long as `inputs`. Its elements before the lost input
hold the values that `format = "list"` returns for those inputs. The
element of the lost input and every element after it are `NULL`. The
check before the first input adds no `results` field. A connection that
fails after the check passes, such as a server that stops during a
request, raises an `httr2_failure` error instead. That error aborts the
batch and carries no `results` field.

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

With `simplify = TRUE` and `logprobs = TRUE`,
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
also raises it for a `logprobs` value that breaks one of these rules.
The `logprobs` value of each `"output_text"` part is checked. A
`logprobs` value, `token`, `logprob`, or `top_logprobs` that is `null`
or absent passes its rule. A `null` step or candidate breaks rule 2 or
rule 5.

1.  The value is an array.

2.  Each step in the array is a JSON object.

3.  The `token` of a step is a string.

4.  The `logprob` of a step is a number.

5.  The `top_logprobs` of a step is an array of JSON objects.

6.  The `token` and `logprob` of each of those objects follow rules 3
    and 4.

The parts are checked in order, then the steps of a part, then the
candidates of a step, one at a time. Within a step, rules 3 and 4 and
the array test of rule 5 come before the candidates. The message names
the first broken rule that this order reaches. These checks run only
after the text of every `"output_text"` part is read, so a reply that
also has a bad `text` in any part gets the text message. Parts of other
types, such as a refusal, are not checked, and with `logprobs = FALSE`
no part is checked. Fields are read by their exact names, so a field
whose name only starts with the one asked for, such as `tokenX`, reads
as absent and gives `NA` in the data frame.

`lms_chat_openai()` raises it in three cases, all only with
`simplify = TRUE`. The first case is a response whose `choices` field is
missing, empty, or not an array, or whose first element is not a JSON
object with a `message` object in it, so there is no reply to read. This
case is raised with or without a `schema`, and with `logprobs = TRUE` as
well. The second case is a reply that does not parse. A `schema` was
given, `logprobs = FALSE`, and the reply content is not one string of
valid JSON. The third case is reply content that is not one string, such
as `null`, a missing `content` field, a number, or an array. A reply
that holds only a tool call has `null` content. This case is raised
without a `schema`, and with `logprobs = TRUE` with or without one. In
the second and third cases, if the server reports the finish reason
`"length"`, the token limit cut the reply off. The message then says so
and names `max_tokens`.
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
can raise the condition through all three chat functions.

[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
does not abort on it. The element of the failed input holds the
condition, or `NA` where the result is text, and the batch warns once
and goes on. See the details of
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md).

The condition carries a `status` field, which holds the HTTP response
status as an integer. Today the status is always 200: each of these
functions reads the body only after a 200, and reports every other
status as an `rlmstudio_api_error` instead. A condition from
`lms_chat_openai()` also carries two more fields. The `content` field
holds the reply content, and the `finish_reason` field holds the finish
reason of the first choice. Both are `NULL` for a response with no
`choices`. In the third case, `content` holds the value that was read,
which is `NULL` for `null` or missing content. For the second and third
cases, the message names the `content` field, so you can read what the
model wrote without a second request. The other messages name
`simplify = FALSE`, which returns the body unchanged, with one
exception. An embeddings body that did not parse at all is checked
before that argument is read, so its message points at the host instead.

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
