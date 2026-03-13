# Check the status of the LM Studio server

Displays the current status of the LM Studio local server via the CLI,
including whether it is running and its configuration.

## Usage

``` r
lms_server_status(
  json = FALSE,
  verbose = FALSE,
  quiet = FALSE,
  log_level = NULL
)
```

## Arguments

- json:

  Logical. Output the status in machine-readable JSON format.

- verbose:

  Logical. Enable detailed logging output.

- quiet:

  Logical. Suppress all logging output.

- log_level:

  Character. The level of logging to use (e.g., "info", "debug").

## Value

A character vector of the raw CLI output. If `json = TRUE` and the
`jsonlite` package is installed, it returns a parsed list or data frame.

## Details

You can only use one logging control flag at a time (`verbose`, `quiet`,
or `log_level`).

## See also

[LM Studio CLI Server Status
Documentation](https://lmstudio.ai/docs/cli/serve/server-status)
