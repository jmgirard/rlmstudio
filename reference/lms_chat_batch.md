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

- `"vector"`: A character vector of responses, with `NA` for an input
  that failed. This format is only supported if `simplify = TRUE` and
  `logprobs = FALSE`. With a `schema`, it warns and returns the list
  instead.

- `"list"`: A list where each element is the response corresponding to
  the provided input, or the condition for an input that failed. With a
  `schema`, `simplify = TRUE`, and `logprobs = FALSE`, each element that
  did not fail is the parsed reply.

- `"data.frame"`: A data.frame containing `input` and `output` columns,
  with `NA` in `output` for an input that failed. If `logprobs = TRUE`,
  an additional list-column named `logprobs` is included, with `NULL`
  for an input that failed. With a `schema` and `logprobs = FALSE`,
  `output` is a list-column of parsed replies, with the condition in
  place of an input that failed. Columns read from each reply follow, as
  described below.

With `api_type = "native"` and `format = "data.frame"`, the data frame
ends with seven columns read from each reply: `response_id`,
`input_tokens`, `total_output_tokens`, `reasoning_output_tokens`,
`tokens_per_second`, `time_to_first_token_seconds`, and
`model_load_time_seconds`. `response_id` is character, and it identifies
the reply on the server. The other six are double, and they come from
the `stats` object of the reply. A cell is `NA` when its field is absent
or is not one value of the column type, a string for `response_id` and a
number for the others. An empty string is a string, so an empty
`response_id` is kept. If `stats` is absent or is not a JSON object, all
six stats cells are `NA`. The server can leave a field out, such as
`model_load_time_seconds`. Such a cell does not fail the input and gives
no warning.

With `api_type = "openresponses"` or `api_type = "openai"` and
`format = "data.frame"`, the data frame ends with four columns read from
each reply: `response_id`, `input_tokens`, `total_output_tokens`, and
`reasoning_output_tokens`. These are the first four native column names,
but the servers send the values under other names:

- `response_id` is the reply's `id` on both routes.

- `input_tokens` is `usage.input_tokens` on the OpenResponses route and
  `usage.prompt_tokens` on the OpenAI route.

- `total_output_tokens` is `usage.output_tokens` on the OpenResponses
  route and `usage.completion_tokens` on the OpenAI route.

- `reasoning_output_tokens` is
  `usage.output_tokens_details.reasoning_tokens` on the OpenResponses
  route and `usage.completion_tokens_details.reasoning_tokens` on the
  OpenAI route.

The columns are there for every setting of `logprobs` and `schema`.
`response_id` is character, and the three counts are double. The `NA`
rule is the one for the native columns: a cell is `NA` when its field is
absent or is not one value of the column type, and an empty string is
kept. If `usage` is absent or is not a JSON object, all three count
cells are `NA`. If the details object is absent or is not a JSON object,
only `reasoning_output_tokens` is `NA`. Such a cell does not fail the
input and gives no warning.

A reply with no readable answer text fails its input, whatever its other
fields hold. The row of an input that failed holds `NA` in every column
read from the reply. If every input failed, those columns are still
there, `response_id` as character and the others as double. The vector
and list formats add no such column.

## Details

This function calls
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
once for each element of `inputs`. It raises `rlmstudio_no_server`
itself, before the first call.

An `rlmstudio_api_error` or an `rlmstudio_bad_response` that
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
raises for one input does not abort the batch. The batch goes on to the
next input. Where the result is a list, or the `output` list-column that
a `schema` gives, the element for that input holds the condition without
its backtrace. An `rlmstudio_bad_response` for reply content that does
not parse keeps that content in its `content` field. Where the result is
text, the element holds `NA`. The result is text with
`format = "vector"` when it returns a vector (`simplify = TRUE`, no
`schema`, `logprobs = FALSE`), and with a data frame whose replies are
not parsed (no `schema`, or `logprobs = TRUE`). The `logprobs` column
holds `NULL` for a failed input. A reply with no readable answer text,
such as one whose content is `null`, fails as an
`rlmstudio_bad_response` in the same way. So does a status-200 body that
does not parse as JSON, such as an HTML page from a proxy or an empty
body. That input fails alone, and the other elements keep their replies.
Use `format = "list"` to keep the conditions. The call gives one warning
that names the count and the positions of the failed inputs. That
warning shows even with `quiet = TRUE`.

An `rlmstudio_no_server` from
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
still aborts the batch. Its `results` field holds the results so far, as
described in the "Server not running" section below. An error of any
other class aborts the batch unchanged.

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
Studio server is there. The call then does not raise
`rlmstudio_no_server`, and what it does depends on what answers. On a
status-200 body that does not parse as JSON, the chat functions,
[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md),
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md),
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
raises it for a model list with another shape, and so do
[`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md)
and
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
without `force = TRUE`, which read that list. The replies of
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
[`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
and
[`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md)
can fail with an error with no class of this package, fail with
`rlmstudio_api_error`, as
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
does for [`{}`](https://rdrr.io/r/base/Paren.html), or report success,
as
[`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md)
does for [`{}`](https://rdrr.io/r/base/Paren.html). A process that does
not answer in HTTP gives an `httr2_failure` error. Use
[`lms_server_ready()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_ready.md)
for the stronger test: it asks the host for a model list and reports
`TRUE` only for a model list that
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
can read.

`lms_chat_batch()` checks the server once before its first input, and
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

`lms_chat_batch()` does not abort on it. The element of the failed input
holds the condition, or `NA` where the result is text, and the batch
warns once and goes on. See the details of `lms_chat_batch()`.

## Malformed response

A condition of class `rlmstudio_bad_response` is raised when the server
answers with a status the wrapper accepts and a body the wrapper cannot
read. It is raised where a wrapper checks the body before it reshapes
it, rather than indexing straight into whatever arrived. Ten functions
raise it:
[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md),
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md),
[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md),
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md),
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md),
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

All ten raise it for a status-200 body that does not parse as JSON, such
as an HTML page from a proxy, JSON text that stops part way, or an empty
body. In the functions that take `simplify`, the body is parsed before
`simplify` is read, so the condition is raised whatever `simplify` is.
The body is parsed by its content and not by its `Content-Type` header,
so valid JSON under `text/plain` is read as JSON. The body is read as
JSON text and nothing else. A body whose text is a URL or the path of a
file does not parse, and the package does not fetch the URL or read the
file. The message says that the body did not parse as JSON and that
something other than LM Studio may be answering on the host. It does not
hold the body text.

[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
also raises it for a status-200 model list with the wrong shape.
[`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md)
and
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
without `force = TRUE` raise it through
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md).
A model list must follow four rules. Each field is read by its exact
name, so a field named `keyX` does not stand in for `key`.

1.  The body is a JSON object whose `models` field is an array. The
    array can be empty.

2.  Each entry of `models` is a JSON object. Its `type` and `key` are
    strings, and its `loaded_instances` is an array.

3.  The `size_bytes` of an entry is a number, or absent, or `null`.

4.  Each entry of `loaded_instances` is a JSON object whose `id` is a
    string with a character that is not whitespace.

The rules are checked before the `type` and `loaded` filters, so an
entry that the filters drop can still raise the condition. The message
names the field or entry that broke a rule.
[`lms_server_ready()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_ready.md)
applies the same rules and returns `FALSE` for a body that breaks one.

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

Apart from a body that does not parse as JSON,
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
`max_tokens`.

With `simplify = TRUE`,
[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md),
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
and
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
also raise it for a body that is a bare JSON value, such as `5`, `"s"`,
or `true`. The message says that the response body is not a JSON object.
A body of `null` gets the message about its missing `output` or
`choices` field instead.
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
can raise the condition through all three chat functions.

`lms_chat_batch()` does not abort on it. The element of the failed input
holds the condition, or `NA` where the result is text, and the batch
warns once and goes on. See the details of `lms_chat_batch()`.

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
returns the body unchanged, with one exception. A body that did not
parse as JSON is checked before that argument is read, so its message
points at the host instead. For such a body, the `content` and
`finish_reason` fields of a condition from
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
are `NULL`.
