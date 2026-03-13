# Run code with the LM Studio daemon active

Temporarily starts the LM Studio headless daemon, executes the provided
R expression, and then gracefully shuts the daemon and any active
servers down. This is ideal for automated scripts and pipelines.

## Usage

``` r
with_lms_daemon(code)
```

## Arguments

- code:

  An R expression to execute while the daemon is running.

## Value

The result of the evaluated code.

## Desktop Users

Be cautious using this wrapper if you already have the LM Studio GUI
open. While the setup phase (`lms_daemon_start`) will succeed, the
teardown phase (`lms_daemon_stop`) will fail because the CLI prevents
programmatic shutdowns of the graphical interface. This wrapper is best
reserved for strictly headless environments or fully automated scripts.

## Examples

``` r
if (FALSE) { # \dontrun{
result <- with_lms_daemon({
  lms_load("llama-3.1-8b")
  lms_chat("llama-3.1-8b", input = "Hello world!")
})
} # }
```
