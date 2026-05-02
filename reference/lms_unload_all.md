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
