# Check whether a host answers as a usable LM Studio server

Sends one GET request to the model list endpoint at `host` and reports
whether the answer came from an LM Studio server that this package can
use. The answer is `TRUE` only when the request returns HTTP status 200
and the response body carries a list of models. An empty list counts,
because a fresh LM Studio install has no models downloaded yet and its
server still works.

## Usage

``` r
lms_server_ready(host = "http://localhost:1234", timeout = 2, token = NULL)
```

## Arguments

- host:

  Character. The base URL of the LM Studio server. Defaults to
  "http://localhost:1234".

- timeout:

  Numeric. The number of seconds to wait for the request before giving
  up. Defaults to 2. A host that opens the port and never answers
  reports `FALSE` after this many seconds.

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

`TRUE` or `FALSE`, always one value. This function raises no condition
of its own for a network failure, a refused connection, an unparsable
body, or a failed status. All of those report `FALSE`. A `token` that is
not one character string and not `NULL` still aborts, because that is a
fault in the call rather than a fact about the server.

## Details

Use this in place of a port check. Another process holding the port, a
server that has not finished starting, and a server that rejects the
token all answer the port and all report `FALSE` here.

## See also

[`lms_server_start()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_start.md)
to start the server.
[`lms_server_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_status.md)
for what the CLI reports about it.

## Examples

``` r
if (FALSE) { # \dontrun{
lms_server_start()

if (lms_server_ready()) {
  list_models()
}

# A server on another port, with a shorter wait
lms_server_ready(host = "http://localhost:8080", timeout = 0.5)
} # }
```
