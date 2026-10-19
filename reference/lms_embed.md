# Turn Text into Embedding Vectors

Sends one or more texts to an embedding model and returns the vector
that the model produced for each one. The texts go out in batches of at
most `batch_size`, one request per batch, in the order given. A reply
that names another model can add one model-list request, as the "Reply
from another model" section describes.

## Usage

``` r
lms_embed(
  model,
  input,
  host = "http://localhost:1234",
  simplify = TRUE,
  ...,
  ttl = NULL,
  token = NULL,
  batch_size = 100,
  quiet = NULL
)
```

## Arguments

- model:

  Character. The loaded embedding model name. Must be one name, given as
  a single string. The string must be valid in its declared encoding and
  not marked `"bytes"`. A class, names, and the S4 bit are removed
  before the name is sent.

- input:

  Character. The texts to embed. A vector of length `n` returns `n`
  embeddings, in the order given. Must hold at least one value and no
  missing values.

- host:

  Character. Server URL.

- simplify:

  `TRUE` or `FALSE`. If `TRUE`, the default, returns a numeric matrix
  with one row per input. `FALSE` returns a list with one element per
  request: the parsed response body, unchanged, or the condition of a
  request that failed. Any other value, `NULL` and `NA` included, aborts
  before the check for a running server.

- ...:

  Additional fields for the request body. LM Studio ignores a field it
  does not recognize, and two OpenAI fields are worth naming for that
  reason: LM Studio ignores `dimensions`, so asking for a narrower
  vector has no effect. `encoding_format = "base64"` is untested against
  LM Studio: a server that honors it returns embeddings this function
  cannot read, and the default `simplify = TRUE` path then aborts.

- ttl:

  A whole number of seconds from 1 to `.Machine$integer.max`, or `NULL`
  to leave it out. It is how long the model stays loaded with no
  request. It has an effect only on a model that this request loads. The
  server loads a model that is not loaded yet when its just-in-time
  loading setting is on. A model that is already loaded keeps its idle
  time.

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

- batch_size:

  A whole number from 1 to `.Machine$integer.max`. The most texts that
  one request carries. The default is 100. A value at least as large as
  `length(input)` sends every text in one request.

- quiet:

  `TRUE`, `FALSE`, or `NULL`, the default. `NULL` follows the
  `rlmstudio.quiet` option. `TRUE` starts no progress bar, and `FALSE`
  starts one, also when the option is `TRUE`. cli draws a started bar
  only after a delay, two seconds by default. A bar starts only when the
  call sends more than one request. Any other value, `NA` included,
  aborts before the check for a running server. `quiet` does not
  suppress the warning about failed inputs.

## Value

If `simplify = FALSE`, a list with one element per request, in request
order. Each element is the parsed JSON body of that request, or the
condition of a request that failed. A call with one request returns a
list of one. Otherwise, a double matrix with one row per input text and
one column per embedding dimension. The row at position `i` holds the
embedding that the response reported for the input at position `i`, or
`NA` for an input whose request failed. The matrix carries no row or
column names.

## Details

Before each request after the first, the function checks again that the
server is running.

A request that fails with an `rlmstudio_bad_response` other than an
`rlmstudio_model_mismatch`, or with an `rlmstudio_api_error` that does
not end the call as described below, fails the inputs it carried alone.
Their rows hold `NA`, or their element of the `simplify = FALSE` list
holds the condition without its backtrace. The call goes on to the next
request and then gives one warning that names the count and the
positions of the failed inputs. That warning shows even with
`quiet = TRUE`. If every request fails, the call aborts with the
condition of the first failed request, and no warning is given.

Four faults end the call at once, and no request goes out after them: a
server that the check before a request, or the model-list lookup of the
reply check, finds gone; an `rlmstudio_api_error` with `status` 401,
403, or 404; an `rlmstudio_api_error` with `status` 400 whose
`server_message` starts with "No models loaded", which LM Studio sent
for an unknown name with no model loaded; and an
`rlmstudio_model_mismatch`, a reply from a model other than the one
asked for. The "API failure" and "Reply from another model" sections
below describe the last two. A fault that ends the call gives no warning
about the inputs that failed before it. With `simplify = TRUE`, a fifth
fault does the same: a request whose embeddings have another number of
dimensions than those of an earlier request. It aborts with
`rlmstudio_bad_response`. With `simplify = FALSE`, the bodies do not go
through the matrix checks, so bodies of two widths are returned with no
abort. Each abort after a request that succeeded carries a `results`
field. With `simplify = TRUE`, it is the matrix so far, with `NA` in
each row whose embedding did not arrive. With `simplify = FALSE`, it is
the list so far, with `NULL` in the element of the request that ended
the call and in every element after it. An abort before any request
succeeded carries no `results` field. An error of any other class aborts
the call unchanged.

On LM Studio 0.4.25+1, the server embeds only the first tokens of each
text, up to the context length of the loaded model instance. For a text
longer than that, it still returns a vector, with no error or warning,
and the vector covers only the start of the text. The `usage` field of
the reply reported 0 tokens on that version, so the count does not show
the cut. The `loaded_instances` column of `list_models(detailed = TRUE)`
gives the `context_length` of each loaded instance. To embed all of a
long text, split it into pieces before the call. Or unload the model
with
[`lms_unload()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md)
and load it again with a larger `context_length` through
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
up to the `max_context_length` column of `list_models(detailed = TRUE)`.
For a model that is already loaded,
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
does not load it again.

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
or
[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md),
a value in the `...` of
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
operating system to give up, which can take a minute. If the hostname of
`host` is `localhost`, in any letter case, or `127.0.0.1`, start the
server with
[`lms_server_start()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_start.md)
and the port of `host`. For the default `host`, that is
`lms_server_start(port = 1234)`. With no `port`, LM Studio uses the port
that it used last. For any other `host`, start the server on the machine
that `host` names, or give `host` the address that your server listens
on. A `host` that does not parse gets this second hint too. The
condition message gives the same hint for the `host` of the call.

The check reads the port and nothing else. Any process holding that port
accepts the connection, so the condition is not raised even though no LM
Studio server is there. The call then does not raise
`rlmstudio_no_server`, and what it does depends on what answers. On a
status-200 body that does not parse as JSON, the chat functions,
`lms_embed()`,
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
`lms_embed()` raise `rlmstudio_bad_response` for it.
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
raises it through them. `lms_embed()` raises it in the same way for the
inputs of that request.
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

`lms_embed()` checks the server before each request, and a request
carries at most `batch_size` inputs. If a check after the first request,
or the check of a model-list lookup, finds the server gone, the call
aborts with `rlmstudio_no_server`. Once a request has succeeded, the
condition carries a `results` field. With `simplify = TRUE`, `results`
is a matrix with `NA` in each row whose embedding did not arrive. With
`simplify = FALSE`, it is a list with one element per batch, with `NULL`
in the element of the request that ended the call and in every element
after it.

## API failure

A condition of class `rlmstudio_api_error` is raised when a REST call
returns a response that the wrapper treats as a failure. The condition
carries a `status` field, which holds the HTTP response status as an
integer. It also carries a `code` field. The field holds the string at
`error.code` of the response body, such as `"model_not_found"`. It is
`NULL` when the body does not parse, when `error` is not a JSON object,
or when its `code` is not one string. A `server_message` field holds the
error text as the server sent it: the `error` string of the body, or
else the string at `error.message`. It is `NULL` when the body does not
parse or holds neither string.

On LM Studio 0.4.26+4 with no model loaded, `/v1/chat/completions`,
`/v1/responses`, and `/v1/embeddings` answered a model name that the
server could not find with status 400, no `code`, and a `server_message`
that starts with "No models loaded".

[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
aborts on it when its `status` is 401, 403, or 404, when its `status` is
400 and its `code` is `"model_not_found"`, and when its `status` is 400
and its `server_message` starts with "No models loaded", in that letter
case. No request goes out after that input. The condition then carries a
`results` field that follows the rule for a lost server in the "Server
not running" section: its elements before the failed input hold the
values that `format = "list"` returns for those inputs, and the element
of the failed input and every element after it are `NULL`. For any other
status, the element of the failed input holds the condition, or `NA`
where the result is text, and the batch warns once and goes on. See the
details of
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md).

`lms_embed()` follows the same rule for each request, except for the
code `"model_not_found"`. A 401, 403, or 404 aborts the call, and so
does a 400 whose `server_message` starts with "No models loaded". Once a
request has succeeded, the condition carries a `results` field, a matrix
or a list as the "Server not running" section describes. Any other
status, a 400 with the code `"model_not_found"` included, fails the
inputs of that request alone, and the call warns once and goes on. If
every request fails, the call aborts with the first condition. See the
details of `lms_embed()`.

## Malformed response

A condition of class `rlmstudio_bad_response` is raised when the server
answers with a status the wrapper accepts and a body the wrapper cannot
read. It is raised where a wrapper checks the body before it reshapes
it, rather than indexing straight into whatever arrived. Eleven
functions raise it for a body they cannot read: `lms_embed()`,
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

## Malformed embeddings

`lms_embed()` raises it on an embeddings block it cannot trust. The
vectors it returns are placed by the index that the response reports, so
a block with a missing, repeated, or out-of-range index would otherwise
pair a vector with the wrong text and give back a matrix that is
silently wrong.

`lms_embed()` reads each request on its own. A bad body, of either kind
that the "Malformed response" section and this section describe, fails
the inputs of that request alone, and the call warns once and goes on.
Unless a stop that the details of `lms_embed()` list ends the call
first, the call aborts with the condition only if every request fails,
and then with the condition of the first. With `simplify = TRUE`, it
also aborts with `rlmstudio_bad_response` for a request whose embeddings
have another number of dimensions than those of an earlier request. That
condition carries a `results` field, a matrix as the "Server not
running" section describes. An `rlmstudio_model_mismatch` also ends the
call, as the "Reply from another model" section says. See the details of
`lms_embed()`.

The messages of `lms_embed()` name `simplify = FALSE`, which returns the
body unchanged, with three exceptions. A body that did not parse as JSON
is checked before that argument is read, so its message points at the
host instead. The messages of `rlmstudio_model_mismatch` and of a failed
model-list lookup do not name it, because the check runs with either
setting of `simplify`.

## Reply from another model

[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md),
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
and `lms_embed()` read the `model` field of each status-200 reply, with
either setting of `simplify`. On LM Studio 0.4.25+1 with one chat model
loaded, both chat routes answered a model name that the server could not
find with status 200 and a reply from the loaded model. With two chat
models loaded, they answered with status 400 and the `code`
`"model_not_found"`, as the "API failure" section describes. On LM
Studio 0.4.26+4 with one embedding model loaded, `/v1/embeddings`
answered a name that it could not find with status 200 and vectors from
the loaded embedding model. The `model` field names the loaded instance
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

Within one call of
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
or `lms_embed()`, a reply whose `model` field a lookup of that call
already accepted for the asked name and the same host is accepted with
no other request. Each such call, and each call of
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
or
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
outside a batch, starts with no accepted ids.

The check runs before the reply is read, so it also runs with
`logprobs = TRUE`, with a `schema` on
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md),
and for a reply with no answer text. In `lms_embed()`, it runs before
the vectors are read. A reply is not checked if its body is not a JSON
object, if it has no `model` field, or if its `model` is not one string
or holds only whitespace. A body that is not a JSON object is returned
with `simplify = FALSE`, and with `simplify = TRUE` it raises the error
that the "Malformed chat reply" section describes, or for `lms_embed()`
the "Malformed embeddings" section. If the instance that answered is
unloaded before the model-list request, the call aborts, also when that
instance belongs to the asked model.

If the model-list request fails, the check raises the condition of that
failure. The message opens with the label of the function, followed by
"because the model-list lookup failed". A status other than 200 raises
`rlmstudio_api_error`. A body that does not parse as JSON, or that
breaks a rule of a model list in the "Malformed model list" section,
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

[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
aborts at the first input that raises `rlmstudio_model_mismatch`, on the
`"openai"` and `"openresponses"` routes. It also aborts at an
`rlmstudio_api_error` with status 400 whose `code` is
`"model_not_found"`, and at one with status 400 whose `server_message`
starts with "No models loaded". No request goes out after that input. In
each case, the condition carries a `results` field that follows the rule
for a lost server in the "Server not running" section.

`lms_embed()` aborts at the first request that raises
`rlmstudio_model_mismatch`, and no request goes out after it. A failed
model-list lookup that raises `rlmstudio_no_server`, or an
`rlmstudio_api_error` that would end the call as an embeddings failure,
such as one with status 401, 403, or 404, ends the call in the same way.
Once a request has succeeded, the condition carries a `results` field, a
matrix or a list as the "Server not running" section describes. Any
other `rlmstudio_api_error` or `rlmstudio_bad_response` from the lookup
fails the inputs of that request alone, as the "API failure" section
describes for a failed request. An error of any other class, such as an
`httr2_failure` from a server that stops during the lookup, aborts the
call unchanged.

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
