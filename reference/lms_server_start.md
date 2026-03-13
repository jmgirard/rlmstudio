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

## Examples

``` r
if (FALSE) { # \dontrun{
# Start on default port
lms_server_start()

# Start on port 3000 with CORS enabled
lms_server_start(port = 3000, cors = TRUE)
} # }
```
