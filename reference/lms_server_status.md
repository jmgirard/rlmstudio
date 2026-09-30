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

  `TRUE` or `FALSE`. Output the status in machine-readable JSON format.
  Any other value, `NULL` and `NA` included, aborts before the `lms` CLI
  runs.

- verbose:

  `TRUE` or `FALSE`. Enable detailed logging output. Any other value,
  `NULL` and `NA` included, aborts before the `lms` CLI runs.

- quiet:

  `TRUE` or `FALSE`. `TRUE` passes `--quiet` to the `lms` CLI, which
  suppresses all logging output. The `rlmstudio.quiet` option does not
  change it. Any other value, `NULL` and `NA` included, aborts before
  the `lms` CLI runs.

- log_level:

  Character. The level of logging to use (e.g., "info", "debug").

## Value

By default, returns a character vector containing the raw CLI output. If
`json = TRUE` and the `jsonlite` package is available, it returns a
parsed list or `data.frame` of the status configuration.

## Details

You can only use one logging control flag at a time (`verbose`, `quiet`,
or `log_level`).

## See also

[LM Studio CLI Server Status
Documentation](https://lmstudio.ai/docs/cli/serve/server-status)

## Examples

``` r
if (FALSE) { # \dontrun{
lms_server_start()

# Get basic status string
lms_server_status()

# Get status as a parsed JSON data frame
lms_server_status(json = TRUE)
} # }
```
