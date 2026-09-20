# Unload a model from memory via REST API

Unload a model from memory via REST API

## Usage

``` r
lms_unload(model, host = "http://localhost:1234", ..., token = NULL)
```

## Arguments

- model:

  Character. Unique identifier (`instance_id`) of the model instance to
  unload. Must be one name, given as a single string.

- host:

  Character. The host address of the local server. Defaults to
  "http://localhost:1234".

- ...:

  Additional arguments passed to the API request body.

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

Invisibly returns a character string representing the unloaded
`instance_id` upon success.

## Note

If you have loaded multiple instances of the same model using
`force = TRUE` in
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
the server assigns them unique instance identifiers (e.g.,
`"google/gemma-3-1b"` and `"google/gemma-3-1b:2"`). Passing the base
model name to `lms_unload()` will only unload the primary instance. To
unload duplicate instances, you must provide their exact `instance_id`,
or use
[`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md)
to clear everything.

## Server not running

Functions that call the LM Studio REST API open a TCP connection to the
hostname and port named in `host` before they send the request. A
function that checks its own arguments does that first, so a bad
`model`, `job_id`, `input`, or `inputs` aborts with an argument message
and no condition class even when the server is down. A condition of
class `rlmstudio_no_server` is raised when that connection cannot be
opened. A refused connection raises it. So do an address the package
cannot parse and a hostname that does not resolve. An address that
neither accepts nor refuses the connection also raises it. That case
waits for the operating system to give up, which can take a minute.
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

## See also

[LM Studio Unload Model
API](https://lmstudio.ai/docs/developer/rest/unload)

## Examples

``` r
if (FALSE) { # \dontrun{
lms_server_start()
lms_download("google/gemma-3-1b")
lms_load("google/gemma-3-1b")

# Unload a single specific model
lms_unload("google/gemma-3-1b")
} # }
```
