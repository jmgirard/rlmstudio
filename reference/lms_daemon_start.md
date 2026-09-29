# Start the LM Studio headless daemon

Launches the `llmster` daemon in the background via the CLI. This is
required in headless environments (such as Linux servers) before loading
models or starting the local server.

## Usage

``` r
lms_daemon_start()
```

## Value

Invisibly returns the CLI exit code, `0`.

## Details

If the CLI exits with a status other than 0, the function aborts. The
message gives the exit code and quotes what the CLI wrote, after "The
CLI said:". The quoted text is the stderr text, or the stdout text if
stderr holds only whitespace and escape codes. A byte that is not valid
UTF-8 shows as `<xx>`, its hex value. ANSI escape codes, such as color
codes, cursor codes, and terminal links, are removed, and each run of
whitespace becomes one space. A text longer than 1000 characters keeps
at most its last 1000 characters, after "…".

## Desktop Users

On desktop operating systems (macOS and Windows), running this command
may actually launch the LM Studio desktop application to act as the
backend engine. If the GUI is already open, this function will simply
detect the active instance and return successfully. While safe to use,
desktop users generally do not need to call this function and can just
open the application manually.

## See also

[LM Studio Headless Daemon
(llmster)](https://lmstudio.ai/docs/developer/core/headless_llmster)

## Examples

``` r
if (FALSE) { # \dontrun{
lms_daemon_start()
} # }
```
