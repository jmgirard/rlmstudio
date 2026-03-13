# List available models

Retrieves a list of models available on your system via the LM Studio
REST API.

## Usage

``` r
list_models(
  loaded = FALSE,
  type = c("llm", "embedding"),
  detailed = FALSE,
  host = "http://localhost:1234"
)
```

## Arguments

- loaded:

  Logical. If `TRUE`, returns only currently loaded models. Defaults to
  `FALSE`.

- type:

  Character vector. The types of models to include. Defaults to
  `c("llm", "embedding")`.

- detailed:

  Logical. Show all information about each model. Defaults to `FALSE`.

- host:

  Character. The host address of the local server.

## Value

A data frame of model information.
