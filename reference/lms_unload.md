# Unload a model from memory via REST API

Unload a model from memory via REST API

## Usage

``` r
lms_unload(model, host = "http://localhost:1234", ...)
```

## Arguments

- model:

  Character. Unique identifier (`instance_id`) of the model instance to
  unload.

- host:

  Character. The host address of the local server. Defaults to
  "http://localhost:1234".

- ...:

  Additional arguments passed to the API request body.

## Value

Invisibly returns the model identifier string on success.

## Note

If you have loaded multiple instances of the same model using
`force = TRUE` in
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
the server assigns them unique instance identifiers (e.g.,
`"google/gemma-3-1b"` and `"google/gemma-3-1b:2"`). Passing the base
model name to `lms_unload()` will only unload the primary instance. To
unload duplicate instances, you must provide their exact `instance_id`,
or use
[`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md)
to clear everything.

## See also

[LM Studio Unload Model
API](https://lmstudio.ai/docs/developer/rest/unload)
