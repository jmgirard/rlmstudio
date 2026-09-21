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

## Call faults that abort

A fault in the call is not a fact about the server, so it aborts rather
than reporting `FALSE`. These messages come from the packages
underneath. The httr2 ones name httr2's own arguments, `url` for `host`
and `seconds` for `timeout`. The curl one names no argument at all. Six
such faults are named below.

- A `host` of `NULL`. httr2 reports that `url` must be a single string,
  not `NULL`.

- A `host` of more than one string. httr2 reports that `url` must be a
  single string, not a character vector.

- A `host` that is a character `NA`. httr2 reports that `url` must be a
  single string, not a character `NA`.

- A `host` that is one string but cannot be parsed as a URL. curl
  reports that it failed to parse the URL and names the reason. A `host`
  holding a space gives "Malformed input to a URL function". An empty
  `host` gives "No host part in the URL".

- A `timeout` below one millisecond. httr2 reports that `seconds` must
  be greater than 1 ms.

- A `timeout` that is not one number, such as a string or a vector of
  two. httr2 reports that `seconds` must be a number, and names either
  the value or its type.

Those six are not the whole list. Any `host` that is not one string
aborts the same way, whatever the reason, and httr2 names either the
value or its type. A `host` of `1` gives "not the number 1". A `host` of
`list("a")` gives "not a list". A `host` of `character(0)` gives "not an
empty character vector".

The `token` fault named above aborts the same way. It comes from this
package rather than from httr2.

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
