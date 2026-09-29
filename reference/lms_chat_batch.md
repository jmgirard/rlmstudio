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
  `logprobs`, `schema`, or `ttl`. A `schema`, a `ttl`, and the
  `api_type` that each needs are checked before the first call. The
  package checks a `stream` here. A `stream` other than `FALSE` or
  `NULL` aborts before the call checks for a running server, because the
  package reads a whole reply and not a streamed one.

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
  place of an input that failed. Columns read from each reply follow
  `output`, or `logprobs` when it is there, as described below. With an
  object `schema` and `logprobs = FALSE`, one column per schema property
  comes after them, as described below.

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
`format = "data.frame"`, the data frame has four columns read from each
reply after `output`, or after `logprobs` when it is there. They are
`response_id`, `input_tokens`, `total_output_tokens`, and
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

With `api_type = "openai"`, `format = "data.frame"`, `logprobs = FALSE`,
and an object `schema`, the data frame ends with one column per
top-level property of the schema, after the four reply columns. An
object schema has a `type` of `"object"`, written as a string or as a
list that holds that one string. Its `properties` is a list of one or
more named entries. Each column has the property name, in the order of
`properties`. The columns come from the schema and not from the replies,
so they are there even when every input failed. The properties of a
nested object get no columns of their own. Any other schema adds no
column.

The type of a property column follows the `type` of the property.
`"string"` gives character, `"integer"` gives integer, `"number"` gives
double, and `"boolean"` gives logical. Each type can be a string or a
list that holds that one string. A pair of one of these types and
`"null"`, such as `c("integer", "null")`, gives the same column type.
Any other `type`, no `type`, or a property that is not a list gives a
list-column.

A cell of a character, integer, double, or logical property column holds
the field of the parsed reply when the field is one value of the column
type. A one-item JSON array counts as one value, and an empty string is
kept. A double column takes any number. An integer column takes an
integer, or a whole number from -2147483647 to 2147483647. Otherwise the
cell is `NA`, and the call gives no warning. The `output` column keeps
the parsed reply, with the value that did not fit. A cell of a
list-column holds the field as parsed, or `NULL` when the field is
absent or `null`. A reply that is not a JSON object, such as an array or
a number, gives `NA` and `NULL` cells. So does the row of an input that
failed.

A property name that is empty, `NA`, repeated, or equal to another
column name aborts before the call checks for a running server. The
other column names are `input`, `output`, `response_id`, `input_tokens`,
`total_output_tokens`, and `reasoning_output_tokens`. A data frame with
`logprobs = TRUE`, and the list and vector formats, do not check the
names.

## Details

This function calls
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
once for each element of `inputs`. It raises `rlmstudio_no_server`
itself, before the first call.

An `rlmstudio_bad_response` that
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
raises for one input fails that input alone, unless it is an
`rlmstudio_model_mismatch`. So does an `rlmstudio_api_error` with any
`status` other than 401, 403, or 404, unless its `status` is 400 and its
`code` is `"model_not_found"`. The batch goes on to the next input.
Where the result is a list, or the `output` list-column that a `schema`
gives, the element for that input holds the condition without its
backtrace. An `rlmstudio_bad_response` for reply content that does not
parse keeps that content in its `content` field. Where the result is
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

An `rlmstudio_api_error` with `status` 401, 403, or 404 aborts the batch
with that condition, and no request goes out after that input. Such a
status comes from a fault that does not depend on the prompt, such as a
token that the server refuses, so every later input fails in the same
way. The condition carries a `results` field, as described in the "API
failure" section below. No warning about failed inputs is given.

The batch aborts in the same way at an `rlmstudio_api_error` with
`status` 400 and the `code` `"model_not_found"`, and at an
`rlmstudio_model_mismatch`. The `"openai"` and `"openresponses"` routes
give these for a model name that the server cannot find, so every later
input fails in the same way. See the "Reply from another model" section
below.

An `rlmstudio_no_server` from
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
also aborts the batch. Its `results` field holds the results so far, as
described in the "Server not running" section below. An error of any
other class aborts the batch unchanged.

## Server not running

Functions that call the LM Studio REST API open a TCP connection to the
hostname and port named in `host` before they send the request. A
function that checks its own arguments does that first, so a bad
`model`, `job_id`, `input`, `inputs`, `messages`, `schema`, `ttl`, or
`batch_size`, a bad `type` or `quiet` of
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
or
[`list_instances()`](https://jmgirard.github.io/rlmstudio/reference/list_instances.md),
a bad `loaded` or `detailed` of
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md),
or a `stream` in the `...` of a chat function, aborts with an argument
message and no condition class even when the server is down. A condition
of class `rlmstudio_no_server` is raised when that connection cannot be
opened. A refused connection raises it. So do an address the package
cannot parse and a hostname that does not resolve. An address that
neither accepts nor refuses the connection also raises it. That case
waits for the operating system to give up, which can take a minute.
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

`lms_chat_batch()` aborts on it when its `status` is 401, 403, or 404,
and when its `status` is 400 and its `code` is `"model_not_found"`. No
request goes out after that input. The condition then carries a
`results` field that follows the rule for a lost server in the "Server
not running" section: its elements before the failed input hold the
values that `format = "list"` returns for those inputs, and the element
of the failed input and every element after it are `NULL`. For any other
status, the element of the failed input holds the condition, or `NA`
where the result is text, and the batch warns once and goes on. See the
details of `lms_chat_batch()`.

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
[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md),
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
unless `force = TRUE`. `lms_chat_batch()` raises it only as
`rlmstudio_model_mismatch`, which the "Reply from another model" section
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

[`list_instances()`](https://jmgirard.github.io/rlmstudio/reference/list_instances.md)
applies the four rules too, and two more. They cover only an entry whose
`type` is in its `type` argument and that has at least one loaded
instance. The `display_name` of such an entry is a string, or absent, or
`null`. The `config` of each of its instances is a JSON object, or
absent, or `null`.
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
and
[`lms_server_ready()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_ready.md)
do not apply these two rules.

[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
[`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
and
[`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md)
also raise it for a status-200 reply of their own with the wrong shape.
Each reply must follow the rule of its function. Each field is read by
its exact name. The rules check the type of a field and not its value,
with four exceptions. The `status` of a load reply must be `"loaded"`. A
download reply whose `status` is `"already_downloaded"` needs no
`job_id`. A download reply whose `status` is `"failed"` always aborts.
The `job_id` of any other download reply must hold a character that is
not whitespace.

1.  A reply of
    [`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
    is a JSON object whose `status` is the string `"loaded"`. With
    `echo_load_config = TRUE`, its `load_config` is also a JSON object.

2.  A reply of
    [`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md)
    is a JSON object whose `status` is a string other than `"failed"`.
    If the status is not `"already_downloaded"`, its `job_id` is a
    string with a character that is not whitespace. For a `"failed"`
    status, the message says that LM Studio reports that the download
    failed. It names the reply's `job_id` if that is a string with a
    character that is not whitespace.

3.  A reply of
    [`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md)
    is a JSON object whose `job_id` and `status` are strings. Its
    `total_size_bytes`, `downloaded_bytes`, and `bytes_per_second` are
    each a number, or absent, or `null`.

For the other faults, the message names the field that broke the rule,
or it says that the body is not a JSON object. It also says that
something other than LM Studio may be answering on the host.

[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
raises it on an embeddings block it cannot trust. The vectors it returns
are placed by the index that the response reports, so a block with a
missing, repeated, or out-of-range index would otherwise pair a vector
with the wrong text and give back a matrix that is silently wrong.

[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
reads each request on its own. A bad body, of either kind above, fails
the inputs of that request alone, and the call warns once and goes on.
The call aborts with the condition only if every request fails, and then
with the condition of the first. With `simplify = TRUE`, it also aborts
with `rlmstudio_bad_response` for a request whose embeddings have
another number of dimensions than those of an earlier request. That
condition carries a `results` field, a matrix as the "Server not
running" section describes. See the details of
[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md).

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
length of the model. The message then says so and names both. A cut-off
reply that is returned as text gives a warning of class
`rlmstudio_reply_cut_off` instead, which
[rlmstudio-conditions](https://jmgirard.github.io/rlmstudio/reference/rlmstudio-conditions.md)
describes.

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

`lms_chat_batch()` does not abort on it, except on the subclass
`rlmstudio_model_mismatch`, as the "Reply from another model" section of
[rlmstudio-conditions](https://jmgirard.github.io/rlmstudio/reference/rlmstudio-conditions.md)
says. The element of the failed input holds the condition, or `NA` where
the result is text, and the batch warns once and goes on. See the
details of `lms_chat_batch()`.

The condition carries a `status` field, which holds the HTTP response
status as an integer. Today the status is always 200: each of these
functions reads the body only after a 200, and reports every other
status as an `rlmstudio_api_error` instead. A condition from
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
about its reply also carries two more fields. A condition from the
model-list lookup does not, as the "Reply from another model" section
says. The `content` field holds the reply content of the first choice,
and the `finish_reason` field holds the finish reason of the first
choice. Both are `NULL` for a response with no `choices`. In the third
case, `content` holds the value that was read, which is `NULL` for
`null` or missing content. For the second, third, and fourth cases, the
message names the `content` field, so you can read what the model wrote
without a second request. The other messages of the chat functions and
[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
name `simplify = FALSE`, which returns the body unchanged, with one
exception. A body that did not parse as JSON is checked before that
argument is read, so its message points at the host instead. For such a
body, the `content` and `finish_reason` fields of a condition from
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
are `NULL`.

## Cut-off reply

A warning of class `rlmstudio_reply_cut_off` is given when a length
limit ended a reply that
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
returns as text. The server reports this with the finish reason
`"length"`. The limit is `max_tokens` or the context length of the
model, and the reply does not say which one. The message names both. The
warning is given with `simplify = TRUE` for reply content that is one
string, in three settings: no `schema`, `logprobs = TRUE`, and a
`schema` with `logprobs = TRUE`. The call returns what the same reply
returns without the cut-off. A `schema` reply with `logprobs = FALSE`
raises `rlmstudio_bad_response` instead, as the "Malformed response"
section says. The warning and that abort read the finish reason of the
first choice, which is the choice that the call reads. No other element
of `choices` is read. With `simplify = FALSE`, the call returns the body
with every choice and no warning.

[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
gives the warning through
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
with `api_type = "openai"`. `lms_chat_batch()` gives one warning of this
class for the whole batch in place of one for each input. It names the
count and the positions of the cut-off inputs, and each of those
elements keeps its reply. It comes after the warning about failed
inputs. A batch that aborts with a `results` field gives this warning
before the abort. It names the cut-off inputs whose replies the
`results` field of the abort holds. The native and OpenResponses routes
give no such warning.

The warning shows whatever `quiet` and the `rlmstudio.quiet` option say,
because it is the only sign that an answer is not complete.

## Reply from another model

[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
and
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
read the `model` field of each status-200 reply, with either setting of
`simplify`. On LM Studio 0.4.25+1 with one chat model loaded, both
routes answered a model name that the server could not find with status
200 and a reply from the loaded model. With two chat models loaded, they
answered with status 400 and the `code` `"model_not_found"`, as the "API
failure" section describes. The `model` field names the loaded instance
that answered. Its id can differ from the key that the call asked for.

If the `model` field equals the name that the call sent, the reply is
accepted. If it differs, the call sends one request for the model list
to `api/v1/models` on the same host, with the token of the call, and
prints no message. The reply is accepted if a model whose key equals the
asked name in any letter case has a loaded instance whose id is the
`model` field. Otherwise the call aborts with a condition of class
`rlmstudio_model_mismatch`. That condition is also an
`rlmstudio_bad_response`, and its `status` is 200. Its `model` field
holds the asked name, and its `reply_model` field holds the `model`
field of the reply. The message names both. A condition from
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
also carries the `content` and `finish_reason` fields, both `NULL`.

The check runs before the reply is read, so it also runs with
`logprobs = TRUE`, with a `schema` on
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md),
and for a reply with no answer text. A reply is not checked if its body
is not a JSON object, if it has no `model` field, or if its `model` is
not one string or holds only whitespace. A body that is not a JSON
object is returned with `simplify = FALSE`, and with `simplify = TRUE`
it raises the error that the "Malformed response" section describes. If
the instance that answered is unloaded before the model-list request,
the call aborts, also when that instance belongs to the asked model.

If the model-list request fails, the call raises the condition of that
failure. The message opens with the label of the chat function, followed
by "because the model-list lookup failed". A status other than 200
raises `rlmstudio_api_error`. A body that does not parse as JSON, or
that breaks a rule of a model list in the "Malformed response" section,
raises `rlmstudio_bad_response`. A server that the port check before the
request cannot reach raises `rlmstudio_no_server`. A condition from the
lookup does not carry the `content` and `finish_reason` fields, also
when
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
raises it.

[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
runs the check through
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
and
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md).
[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md)
does not check the reply. On LM Studio 0.4.25+1, `/api/v1/chat` answered
a name that it could not find with status 404, which raises
`rlmstudio_api_error`.

`lms_chat_batch()` aborts at the first input that raises
`rlmstudio_model_mismatch`, on the `"openai"` and `"openresponses"`
routes. It also aborts at an `rlmstudio_api_error` with status 400 whose
`code` is `"model_not_found"`. No request goes out after that input. In
both cases, the condition carries a `results` field that follows the
rule for a lost server in the "Server not running" section.
