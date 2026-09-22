# Unload all models from memory

Retrieves a list of all currently loaded models and unloads them one by
one.

## Usage

``` r
lms_unload_all(host = "http://localhost:1234", ..., token = NULL)
```

## Arguments

- host:

  Character. The host address of the local server. Defaults to
  "http://localhost:1234".

- ...:

  Additional arguments passed to the API request body for each unload
  request.

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

Invisibly returns a character vector of the `instance_id`s that were
successfully unloaded. If no models were currently loaded, it invisibly
returns `NULL`.

## Details

This function calls
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
to find the loaded instances, then calls
[`lms_unload()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md)
once for each one. It raises `rlmstudio_no_server` itself, before the
first call. It can raise `rlmstudio_api_error` through
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
and through
[`lms_unload()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md).

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

## See also

[`lms_unload`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md)

## Examples

``` r
if (FALSE) { # \dontrun{
lms_server_start()
lms_download("google/gemma-3-1b")
lms_load("google/gemma-3-1b")

# Unload all currently loaded models to clear VRAM
lms_unload_all()
} # }
```
