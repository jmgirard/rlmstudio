# Stop the LM Studio headless daemon

Stops the `llmster` daemon via the CLI. Use this to clean up system
resources when you are completely finished using LM Studio in headless
mode.

## Usage

``` r
lms_daemon_stop(force = FALSE)
```

## Arguments

- force:

  Logical. If `TRUE`, attempts to stop the local server before shutting
  down the daemon. The daemon cannot be stopped while the server is
  actively running. Defaults to `FALSE`.

## Value

Invisibly returns the system exit code (0 for success).

## Desktop Users

If the daemon is currently being managed by the LM Studio desktop
application, this function will fail. The CLI intentionally prevents
programmatic shutdowns of the GUI to avoid disrupting visual sessions.
In this scenario, you must close the desktop application manually.

## Examples

``` r
if (FALSE) { # \dontrun{
lms_daemon_stop(force = TRUE)
} # }
```
