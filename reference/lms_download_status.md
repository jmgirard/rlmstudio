# Get the status of a download job

Get the status of a download job

## Usage

``` r
lms_download_status(job_id, host = "http://localhost:1234", token = NULL)
```

## Arguments

- job_id:

  Character. The unique identifier for the download job. Must be one id,
  given as a single string. The string must be valid in its declared
  encoding and not marked `"bytes"`. A class, names, and the S4 bit are
  removed before the id is sent.

- host:

  Character. The host address of the local server. Defaults to
  "http://localhost:1234".

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

An object of class `lms_download_status` containing the download status.

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
`lms_download_status()`, and
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
and `lms_download_status()` raise it for a reply of their own with
another shape, such as [`{}`](https://rdrr.io/r/base/Paren.html). A
process that does not answer in HTTP gives an `httr2_failure` error. Use
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
[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md),
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md),
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md),
[`list_instances()`](https://jmgirard.github.io/rlmstudio/reference/list_instances.md),
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
[`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
`lms_download_status()`, and
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

## Malformed load or download reply

[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
[`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
and `lms_download_status()` also raise it for a status-200 reply of
their own with the wrong shape. Each reply must follow the rule of its
function. Each field is read by its exact name. The rules check the type
of a field and not its value, with four exceptions. The `status` of a
load reply must be `"loaded"`. A download reply whose `status` is
`"already_downloaded"` needs no `job_id`. A download reply whose
`status` is `"failed"` always aborts. The `job_id` of any other download
reply must hold a character that is not whitespace.

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

3.  A reply of `lms_download_status()` is a JSON object whose `job_id`
    and `status` are strings. Its `total_size_bytes`,
    `downloaded_bytes`, and `bytes_per_second` are each a number, or
    absent, or `null`.

For the other faults, the message names the field that broke the rule,
or it says that the body is not a JSON object. It also says that
something other than LM Studio may be answering on the host.

## See also

[LM Studio Download Status
API](https://lmstudio.ai/docs/developer/rest/download-status)

## Examples

``` r
if (FALSE) { # \dontrun{
lms_server_start()

job_id <- lms_download("google/gemma-3-1b")
status <- lms_download_status(job_id)
print(status)
} # }
```
