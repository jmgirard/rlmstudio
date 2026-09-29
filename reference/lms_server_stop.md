# Stop the LM Studio local server

Stops the currently running LM Studio local server via the CLI.

## Usage

``` r
lms_server_stop()
```

## Value

Invisibly returns an integer representing the system exit code (`0` for
success).

## Details

If the CLI exits with a status other than 0, the function reads what the
CLI wrote. If the text says "not running", the function prints an info
message and returns the exit code invisibly, with no abort. Letter case
does not matter. With no server running, the CLI exits with status 1 and
says so.
[`lms_daemon_stop()`](https://jmgirard.github.io/rlmstudio/reference/lms_daemon_stop.md)
with `force = TRUE` shows the same message.

Any other failure aborts. The message gives the exit code and quotes
what the CLI wrote, after "The CLI said:". The quoted text is the stderr
text, or the stdout text if stderr holds only whitespace and escape
codes. A byte that is not valid UTF-8 shows as `<xx>`, its hex value.
ANSI escape codes, such as color codes, cursor codes, and terminal
links, are removed, and each run of whitespace becomes one space. A text
longer than 1000 characters keeps at most its last 1000 characters,
after "…".

## See also

[LM Studio CLI Server Stop
Documentation](https://lmstudio.ai/docs/cli/serve/server-stop)

## Examples

``` r
if (FALSE) { # \dontrun{
lms_server_start()
lms_server_stop()
} # }
```
