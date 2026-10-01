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
  previous_response_id = NULL,
  store = NULL,
  token = NULL
)
```

## Arguments

- model:

  Character. The loaded model name. Must be one name, given as a single
  string. The string must be valid in its declared encoding and not
  marked `"bytes"`. A class, names, and the S4 bit are removed before
  the name is sent.

- input:

  Character. The user prompt, as one string. A character vector must
  hold no missing values, and its length must be one. Any other
  character value aborts before the check for a running server. To send
  several prompts, one request each, use
  [`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md).
  A list is sent as given in the `input` field.

- system_prompt:

  Character. Optional system prompt.

- host:

  Character. Server URL.

- simplify:

  `TRUE` or `FALSE`. If `TRUE`, parses output to text. Any other value,
  `NULL` and `NA` included, aborts before the check for a running
  server.

- ...:

  Additional API arguments. This endpoint rejects a `ttl` field with
  status 400, which raises `rlmstudio_api_error`. The package checks a
  `stream` here. A `stream` other than `FALSE` or `NULL` aborts before
  the call checks for a running server, because the package reads a
  whole reply and not a streamed one. The package also checks each
  element named exactly `logprobs`. It must be `TRUE`, `FALSE`, or
  `NULL`, and any other value aborts before the check for a running
  server. The endpoint has no logprobs, so no `logprobs` field goes into
  the request body, and a `TRUE` warns.

- previous_response_id:

  One string, a value that carries a `response_id` attribute, or `NULL`.
  It names the stored reply that this chat continues. Pass an earlier
  reply of this function itself, such as `first`, or its id,
  `attr(first, "response_id")`. A value that carries a `response_id`
  attribute sends that attribute in place of the value, also when the
  value is a list or is itself an id. Only that exact attribute name is
  read. A value with no such attribute is sent as the id itself. So a
  reply that came back with no id, such as a reply of this function sent
  with `store = FALSE`, goes out as its own text, and the call raises
  `rlmstudio_api_error` with status 400. A reply text that breaks the id
  rules below, such as an empty text or a text of whitespace only,
  aborts before the request, as such an id does. The character vector
  that
  [`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
  returns with `format = "vector"` and the `output` column of its data
  frame carry no attribute. The data frame holds the ids in its
  `response_id` column.

  The id, the attribute when there is one, must be valid in its declared
  encoding and not marked `"bytes"`. A class, names, and the S4 bit are
  removed before the id is sent. `NULL`, the default, starts a new
  thread. As the id, `NA`, an empty string, a string of whitespace only,
  a value that is not a string, and more or fewer than one string abort
  before the check for a running server. For an attribute, the message
  names the attribute. Only this exact argument name is checked. A
  shortened name, such as `previous`, goes into the request body
  unchecked, under the name you wrote. An id that the server does not
  hold raises `rlmstudio_api_error` with status 400 and the `code`
  `"invalid_value"`.
  [`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
  and
  [`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
  refuse an id or a value that carries one with `api_type = "openai"`,
  because the OpenAI chat endpoint keeps no thread.
  [`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
  has no such argument. A `previous_response_id` in its `...` goes into
  the request body unchecked, and the endpoint ignores it.

- store:

  `TRUE`, `FALSE`, or `NULL`. Whether the server stores the reply, so
  that a later call can continue from its id. `NULL`, the default, sends
  no `store` field, so the server default applies, and that default
  stores the reply. `TRUE` and `FALSE` go out as a plain JSON `true` or
  `false`, also when the value has names, dimensions, or a class. Any
  other value, `NA` included, aborts before the check for a running
  server. Only this exact name is checked. A shortened name, such as
  `sto`, goes into the request body unchecked, under the name you wrote.
  [`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
  and
  [`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
  refuse `TRUE` or `FALSE` with `api_type = "openai"`.

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

If `simplify = FALSE`, returns a list representing the raw JSON
response. A status-200 body that does not parse as JSON raises
`rlmstudio_bad_response` with either setting of `simplify`. The body can
hold a `response_id` for the reply and a `stats` object of token counts
and timings. With `api_type = "native"` and `format = "data.frame"`,
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
returns the id and six of the `stats` fields as columns. If
`simplify = TRUE`, returns one character string: the `content` of every
item of type `"message"` in the `output` array, pasted together in order
with no separator. Items of other types, such as reasoning and tool
calls, are skipped. A reply with no readable answer text raises
`rlmstudio_bad_response`, as described below.

With `simplify = TRUE`, the string carries the `response_id` field of
the reply in a `response_id` attribute. Pass the string itself as
`previous_response_id` to continue the thread, and the attribute is
sent. The string has no attribute when `response_id` is absent or is not
one string. A reply sent with `store = FALSE` has no `response_id`
field, so its string has no attribute, and there is no id to continue
from.
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
reads the attribute from the `id` field of its reply instead. An
OpenResponses reply sent with `store = FALSE` still has an `id`, so its
value carries the attribute, but the server does not hold that reply. A
later OpenResponses call that passes that id as `previous_response_id`
raises `rlmstudio_api_error` with status 400 and the `code`
`"previous_response_not_found"`.

## Server not running

Functions that call the LM Studio REST API open a TCP connection to the
hostname and port named in `host` before they send the request. A
function that checks its own arguments does that first, so a bad
`model`, `job_id`, `input`, `inputs`, `messages`, `schema`, `ttl`,
`previous_response_id`, or `batch_size`, a bad `type` of
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
or
[`list_instances()`](https://jmgirard.github.io/rlmstudio/reference/list_instances.md),
a bad `TRUE` or `FALSE` argument such as `simplify`, `logprobs`,
`quiet`, `force`, or `store`, a `store` on the `"openai"` route of
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
or
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md),
a `stream` in the `...` of a chat function, a `logprobs` in the `...` of
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
or `lms_chat_native()`, a value in the `...` of
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
that
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
reads as an argument already given, an `instructions` or `messages` in
the `...` of
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
or
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
on the route where
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
sets it, or a name, id, or `type` string that is not valid in its
encoding or is marked as bytes, aborts with an argument message and no
condition class even when the server is down. A condition of class
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
Studio server is there. The call then does not raise
`rlmstudio_no_server`, and what it does depends on what answers. On a
status-200 body that does not parse as JSON, the chat functions,
[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md),
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md),
[`list_instances()`](https://jmgirard.github.io/rlmstudio/reference/list_instances.md),
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
[`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
[`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md),
and
[`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md)
raise `rlmstudio_bad_response`.
[`lms_unload()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md)
does not read the body, so it can report success. A body that parses as
JSON but has another shape can come back unchanged with
`simplify = FALSE`. With `simplify = TRUE`, the chat functions and
[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
raise `rlmstudio_bad_response` for it.
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
and
[`list_instances()`](https://jmgirard.github.io/rlmstudio/reference/list_instances.md)
raise it for a model list with another shape, and so do
[`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md)
and
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
without `force = TRUE`, which read that list.
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
and
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
raise it for such a model list too, with either setting of `simplify`,
through the model lookup that a reply from another model starts.
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
raises it through them.
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
[`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
and
[`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md)
raise it for a reply of their own with another shape, such as
[`{}`](https://rdrr.io/r/base/Paren.html). A process that does not
answer in HTTP gives an `httr2_failure` error. Use
[`lms_server_ready()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_ready.md)
for the stronger test: it asks the host for a model list and reports
`TRUE` only for a model list that
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
can read.

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

[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
checks the server before each request, and a request carries at most
`batch_size` inputs. If a check after the first request finds the server
gone, the call aborts with `rlmstudio_no_server`. Once a request has
succeeded, the condition carries a `results` field. With
`simplify = TRUE`, `results` is a matrix with `NA` in each row whose
embedding did not arrive. With `simplify = FALSE`, it is a list with one
element per batch, with `NULL` in the element of the request that ended
the call and in every element after it.

## API failure

A condition of class `rlmstudio_api_error` is raised when a REST call
returns a response that the wrapper treats as a failure. The condition
carries a `status` field, which holds the HTTP response status as an
integer. It also carries a `code` field. The field holds the string at
`error.code` of the response body, such as `"model_not_found"`. It is
`NULL` when the body does not parse, when `error` is not a JSON object,
or when its `code` is not one string.

[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
aborts on it when its `status` is 401, 403, or 404, and when its
`status` is 400 and its `code` is `"model_not_found"`. No request goes
out after that input. The condition then carries a `results` field that
follows the rule for a lost server in the "Server not running" section:
its elements before the failed input hold the values that
`format = "list"` returns for those inputs, and the element of the
failed input and every element after it are `NULL`. For any other
status, the element of the failed input holds the condition, or `NA`
where the result is text, and the batch warns once and goes on. See the
details of
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md).

[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
follows the same rule for each request. A 401, 403, or 404 aborts the
call, and once a request has succeeded the condition carries a `results`
field, a matrix or a list as the "Server not running" section describes.
Any other status fails the inputs of that request alone, and the call
warns once and goes on. If every request fails, the call aborts with the
first condition. See the details of
[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md).

## Malformed response

A condition of class `rlmstudio_bad_response` is raised when the server
answers with a status the wrapper accepts and a body the wrapper cannot
read. It is raised where a wrapper checks the body before it reshapes
it, rather than indexing straight into whatever arrived. Eleven
functions raise it for a body they cannot read:
[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md),
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md),
`lms_chat_native()`,
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md),
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md),
[`list_instances()`](https://jmgirard.github.io/rlmstudio/reference/list_instances.md),
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
[`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
[`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md),
and
[`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md).
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
raises it through the chat function it calls.
[`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md)
raises it through
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md),
and so does
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
unless `force = TRUE`.
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
raises it only as `rlmstudio_model_mismatch`, which the "Reply from
another model" section of
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
describes.

All eleven raise it for a status-200 body that does not parse as JSON,
such as an HTML page from a proxy, JSON text that stops part way, or an
empty body. In the functions that take `simplify`, the body is parsed
before `simplify` is read, so the condition is raised whatever
`simplify` is. The body is parsed by its content and not by its
`Content-Type` header, so valid JSON under `text/plain` is read as JSON.
The body is read as JSON text and nothing else. A body whose text is a
URL or the path of a file does not parse, and the package does not fetch
the URL or read the file. The message says that the body did not parse
as JSON and that something other than LM Studio may be answering on the
host. It does not hold the body text.

The condition carries a `status` field, which holds the HTTP response
status as an integer. Today the status is always 200: each of these
functions reads the body only after a 200, and reports every other
status as an `rlmstudio_api_error` instead.

## Malformed chat reply

`lms_chat_native()` and
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
raise it with `simplify = TRUE` when the reply holds no readable answer
text. Both read the answer from the items of type `"message"` in the
`output` array. They raise it when `output` is missing, empty, or not an
array, or when an item in it is not a JSON object. They also raise it
when no item has the type `"message"`, as in a reply that holds only
reasoning or a tool call. The text of a message must be one string. For
`lms_chat_native()` that is the `content` of the item. For
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
it is the `text` of each part of type `"output_text"`. For
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
only, the `content` of each message must be an array of JSON objects,
and the messages together must hold at least one `"output_text"` part.

Apart from a body that does not parse as JSON,
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
raises it in four cases, all only with `simplify = TRUE`. The first case
is a response whose `choices` field is missing, empty, or not an array,
or whose first element is not a JSON object with a `message` object in
it, so there is no reply to read. This case is raised with or without a
`schema`, and with `logprobs = TRUE` as well. The second case is a reply
that does not parse. A `schema` was given, `logprobs = FALSE`, and the
reply content is not one string of valid JSON. The third case is reply
content that is not one string, such as `null`, a missing `content`
field, a number, or an array. A reply that holds only a tool call has
`null` content. This case is raised without a `schema`, and with
`logprobs = TRUE` with or without one. The fourth case is a cut-off
reply. A `schema` was given, `logprobs = FALSE`, and the server reports
the finish reason `"length"`. This case is raised also when the reply
content parses, because a reply that stops part way can parse to a wrong
value, such as the first digit of a longer number. In the second, third,
and fourth cases, if the server reports the finish reason `"length"`, a
length limit ended the reply. The limit is `max_tokens` or the context
length of the model. The message then says so and names both.

With `simplify = TRUE`, `lms_chat_native()`,
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
and
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
also raise it for a body that is a bare JSON value, such as `5`, `"s"`,
or `true`. The message says that the response body is not a JSON object.
A body of `null` gets the message about its missing `output` or
`choices` field instead.
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
can raise the condition through all three chat functions.

[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
does not abort on it, except on the subclass `rlmstudio_model_mismatch`,
as the "Reply from another model" section of
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
says. The element of the failed input holds the condition, or `NA` where
the result is text, and the batch warns once and goes on. See the
details of
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md).

A condition from
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
about its reply also carries two more fields. A condition from the
model-list lookup does not, as the "Reply from another model" section of
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
says. The `content` field holds the reply content of the first choice,
and the `finish_reason` field holds the finish reason of the first
choice. Both are `NULL` for a response with no `choices`. In the third
case, `content` holds the value that was read, which is `NULL` for
`null` or missing content. For the second, third, and fourth cases, the
message names the `content` field, so you can read what the model wrote
without a second request. The other messages of the chat functions about
the reply name `simplify = FALSE`, which returns the body unchanged,
with one exception. A body that did not parse as JSON is checked before
that argument is read, so its message points at the host instead. For
such a body, the `content` and `finish_reason` fields of a condition
from
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
are `NULL`. The messages of `rlmstudio_model_mismatch` and of the
model-list lookup do not name `simplify = FALSE`, because the check runs
with either setting of `simplify`.
