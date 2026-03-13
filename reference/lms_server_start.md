# Start the LM Studio local server

Launches the LM Studio local server via the CLI, allowing you to
interact with loaded models via HTTP API calls.

## Usage

``` r
lms_server_start(port = NULL, cors = FALSE)
```

## Arguments

- port:

  Integer. Port to run the server on. If not provided, LM Studio uses
  the last used port.

- cors:

  Logical. Enable CORS support for web application development. Defaults
  to FALSE.

## Value

Invisibly returns the system exit code (0 for success).

## See also

[LM Studio CLI Server Start
Documentation](https://lmstudio.ai/docs/cli/serve/server-start)
