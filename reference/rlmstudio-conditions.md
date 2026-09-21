# Error conditions raised by rlmstudio

The functions in this package that talk to the LM Studio REST API raise
three condition classes of their own. Each one is raised through
[`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html), so
each one is an R error that you can catch by class with
[`base::tryCatch()`](https://rdrr.io/r/base/conditions.html).

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
tryCatch(
  list_models(host = "http://localhost:9999"),
  rlmstudio_no_server = function(cnd) {
    message("The server is not running: ", conditionMessage(cnd))
  },
  rlmstudio_api_error = function(cnd) {
    message("The API call failed with status ", cnd$status)
  },
  rlmstudio_bad_response = function(cnd) {
    message("The response body could not be read: ", conditionMessage(cnd))
  }
)
} # }
```
