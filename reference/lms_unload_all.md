# Unload all models from memory

Retrieves a list of all currently loaded models and unloads them one by
one.

## Usage

``` r
lms_unload_all(host = "http://localhost:1234", ...)
```

## Arguments

- host:

  Character. The host address of the local server. Defaults to
  "http://localhost:1234".

- ...:

  Additional arguments passed to the API request body for each unload
  request.

## Value

Invisibly returns a character vector of the `instance_id`s that were
successfully unloaded. If no models were currently loaded, it invisibly
returns `NULL`.

## Details

This function calls
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
to find the loaded instances, then calls
[`lms_unload()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md)
once for each one. It raises `rlmstudio_no_server` itself, before the
first call. It can raise `rlmstudio_api_error` through
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
and through
[`lms_unload()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md).

## Server not running

Functions that call the LM Studio REST API check that a server answers
at the `host` address. A condition of class `rlmstudio_no_server` is
raised when the LM Studio server is not running. Start the server with
[`lms_server_start()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_start.md),
or give `host` the address that your server listens on.

## API failure

A condition of class `rlmstudio_api_error` is raised when a REST call
returns a response that the wrapper treats as a failure. The condition
carries a `status` field, which holds the HTTP response status as an
integer.

## See also

[`lms_unload`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md)

## Examples

``` r
if (FALSE) { # \dontrun{
lms_server_start()
lms_download("google/gemma-3-1b")
lms_load("google/gemma-3-1b")

# Unload all currently loaded models to clear VRAM
lms_unload_all()
} # }
```
