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

Invisibly returns a character vector of the unloaded model instance
identifiers, or `NULL` if no models were loaded.

## See also

[`lms_unload`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md)
