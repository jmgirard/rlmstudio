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
  actively running. Defaults to `FALSE`. If no server is running, the
  message of
  [`lms_server_stop()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_stop.md)
  says so.

## Value

Invisibly returns `TRUE` if the daemon stopped or was not running, and
`FALSE` if the LM Studio GUI manages it.

## Details

If the CLI exits with a status other than 0, the function reads what the
CLI wrote. If the text says that the daemon is part of LM Studio, the
function prints an info message and returns `FALSE`. If the text says
that the daemon is not running, it prints an info message and returns
`TRUE`. Letter case does not matter. Any other failure aborts. The
message gives the exit code, quotes what the CLI wrote after "The CLI
said:", and gives a hint about `force = TRUE`. The quoted text is the
stderr text, or the stdout text if stderr holds only whitespace and
escape codes. A byte that is not valid UTF-8 shows as `<xx>`, its hex
value. ANSI escape codes, such as color codes, cursor codes, and
terminal links, are removed, and each run of whitespace becomes one
space. A text longer than 1000 characters keeps at most its last 1000
characters, after "…".

## Desktop Users

If the daemon is currently being managed by the LM Studio desktop
application, the CLI does not stop it. The CLI intentionally prevents
programmatic shutdowns of the GUI to avoid disrupting visual sessions.
This function then returns `FALSE`, and the daemon keeps running. In
this scenario, you must close the desktop application manually.

## Examples

``` r
if (FALSE) { # \dontrun{
lms_daemon_stop(force = TRUE)
} # }
```
