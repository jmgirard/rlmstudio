# Start the LM Studio local server

Launches the LM Studio local server via the CLI, allowing you to
interact with loaded models via HTTP API calls.

## Usage

``` r
lms_server_start(
  port = NULL,
  cors = FALSE,
  wait = 10,
  host = NULL,
  token = NULL
)
```

## Arguments

- port:

  Integer. Port to run the server on. If not provided, LM Studio uses
  the last used port.

- cors:

  Logical. Enable CORS support for web application development. Defaults
  to FALSE.

- wait:

  Numeric. How many seconds to keep asking the REST API whether it is
  ready. Defaults to 10. With `wait = 0` the function sends no readiness
  request and returns as soon as the CLI does. A `wait` that is not one
  number, zero or more, aborts before the CLI runs.

- host:

  Character or `NULL`. The base URL to ask. This says where to look for
  the server that was started. It does not change where the CLI starts
  it, which only `port` does. `NULL` picks a host as described below.

- token:

  Character or `NULL`. An API token for the readiness request, for a
  server that requires authentication. `NULL` reads the
  `rlmstudio.token` option and then the `RLMSTUDIO_API_TOKEN`
  environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

Invisibly returns an integer representing the system exit code (`0` for
success).

## Details

The CLI returns before the REST API answers. By default this function
then keeps asking the REST API whether it is ready, for about `wait`
seconds, and returns once it answers. A script that calls the REST API
on the next line therefore no longer reports a missing server on a
healthy machine. The budget is not a hard cap. No new request starts
once `wait` seconds have passed, but a request already in flight is
allowed one second to finish. With no `host` and no `port`, the function
first asks the CLI which port the server uses, and that read runs before
the `wait` seconds start to count.

## Which host the wait asks

The host is picked in this order.

- A `host` you give wins.

- With no `host` and a `port`, the host is `http://localhost:<port>`.

- With neither, the port that `lms_server_status(json = TRUE)` reports
  is read, and the host is `http://localhost:` plus that port.

The request carries `token`, read as described under that argument.

Beside a bad `wait`, two faults in the call abort before the CLI runs,
with any `wait`. One is a `host` that is not `NULL` and that the
readiness request cannot be built from, such as a vector of two strings,
`NA`, an empty string, or `"localhost:1234"`, which lacks `http://`.
That message names `host` and quotes the reason httr2 or curl gave. The
other is a `token` that is not one character string and not `NULL`.

A wait that runs out does not abort. The server was already started and
that cannot be undone, so the function raises a warning and returns the
CLI exit code. A call with no `host` and no `port` whose port read
yields nothing raises its own warning and sends no readiness request. If
the readiness check itself aborts during the wait, the function raises a
third warning. It names the host, quotes the abort message, and the
function returns the CLI exit code. None of the three warnings is
silenced by the `rlmstudio.quiet` option.

## See also

[LM Studio CLI Server Start
Documentation](https://lmstudio.ai/docs/cli/serve/server-start).
[`lms_server_ready()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_ready.md)
for the readiness check this function calls.

## Examples

``` r
if (FALSE) { # \dontrun{
# Start server on the default port and wait for the REST API
lms_server_start()

# Start server on a custom port with CORS enabled
lms_server_start(port = 8080, cors = TRUE)

# Return as soon as the CLI does, without waiting
lms_server_start(wait = 0)

# Wait longer, and ask a host the rules above would not pick
lms_server_start(wait = 60, host = "http://127.0.0.1:1234")
} # }
```
