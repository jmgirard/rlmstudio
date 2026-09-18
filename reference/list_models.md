# List available models

Retrieves a list of models available on your system via the LM Studio
REST API.

## Usage

``` r
list_models(
  loaded = FALSE,
  type = c("llm", "embedding"),
  detailed = FALSE,
  quiet = FALSE,
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

- quiet:

  Logical. If `TRUE`, suppresses informative console messages. Defaults
  to `FALSE`. Does not suppress the abort raised when the server is not
  running.

- host:

  Character. The host address of the local server.

## Value

A `data.frame` containing information about the available models. By
default, it includes columns for `state`, `type`, `display_name`, `key`,
`architecture`, and `size_gb`. If `detailed = TRUE`, it returns a
comprehensive `data.frame` including all raw metadata columns provided
by the API. Returns an empty `data.frame` if no models match the
criteria.

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

[LM Studio List Models
API](https://lmstudio.ai/docs/developer/rest/list)

## Examples

``` r
if (FALSE) { # \dontrun{
lms_server_start()
lms_download("google/gemma-3-1b")
lms_load("google/gemma-3-1b")

# List all downloaded models
list_models()

# List only currently loaded models
list_models(loaded = TRUE)

# Get detailed information about loaded text models
list_models(loaded = TRUE, type = "llm", detailed = TRUE)
} # }
```
