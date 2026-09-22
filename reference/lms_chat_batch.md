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
  place of an input that failed.

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
its backtrace. An `rlmstudio_bad_response` for a reply that does not
parse keeps the reply content in its `content` field. Where the result
is text, the element holds `NA`. The result is text with
`format = "vector"` when it returns a vector (`simplify = TRUE`, no
`schema`, `logprobs = FALSE`), and with a data frame whose replies are
not parsed (no `schema`, or `logprobs = TRUE`). The `logprobs` column
holds `NULL` for a failed input. A reply that
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
returns as `NULL`, such as one whose content is `null`, also holds `NA`
in a text result. Use `format = "list"` to keep the conditions. The call
then gives one warning that names the count and the positions of the
failed inputs. That warning shows even with `quiet = TRUE`.

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
Studio server is there. The call then fails later, as an
`rlmstudio_api_error` or as a raw parse error, rather than as
`rlmstudio_no_server`. Use
[`lms_server_ready()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_ready.md)
for the stronger test: it asks the host for a model list and reports
`TRUE` only for an answer that an LM Studio server would give.

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
it, rather than indexing straight into whatever arrived. Two functions
raise it.

[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
raises it on an embeddings block it cannot trust. The vectors it returns
are placed by the index that the response reports, so a block with a
missing, repeated, or out-of-range index would otherwise pair a vector
with the wrong text and give back a matrix that is silently wrong.

[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
raises it in two cases, both only with `simplify = TRUE`. The first case
is a response whose `choices` field is missing, empty, or not an array,
or whose first element is not a JSON object with a `message` object in
it, so there is no reply to read. This case is raised with or without a
`schema`, and with `logprobs = TRUE` as well. The second case is a reply
that does not parse. A `schema` was given, `logprobs = FALSE`, and the
reply content is not one string of valid JSON. If the server reports the
finish reason `"length"`, the token limit cut the reply off. The message
then says so and names `max_tokens`.
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
can raise the condition through
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md).

`lms_chat_batch()` does not abort on it. The element of the failed input
holds the condition, or `NA` where the result is text, and the batch
warns once and goes on. See the details of `lms_chat_batch()`.

The condition carries a `status` field, which holds the HTTP response
status as an integer. Today the status is always 200: both functions
read the body only after a 200, and report every other status as an
`rlmstudio_api_error` instead. A condition from
[`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
also carries two more fields. The `content` field holds the reply
content, and the `finish_reason` field holds the finish reason that the
server reported. Either one is `NULL` where the response has none, and
both are `NULL` for a response with no `choices`. For a reply that does
not parse, the message names the `content` field, so you can read what
the model wrote without a second request. The other messages name
`simplify = FALSE`, which returns the body unchanged, with one
exception. An embeddings body that did not parse at all is checked
before that argument is read, so its message points at the host instead.
