# Start the LM Studio headless daemon

Launches the `llmster` daemon in the background via the CLI. This is
required in headless environments (such as Linux servers) before loading
models or starting the local server.

## Usage

``` r
lms_daemon_start()
```

## Value

Invisibly returns the process object (or 0 if already running).

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
