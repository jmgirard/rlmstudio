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

Invisibly returns `TRUE` on success.

## See also

[LM Studio Unload Model
API](https://lmstudio.ai/docs/developer/rest/unload)
