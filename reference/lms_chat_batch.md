# Batch Chat Completion with LM Studio

Process a vector of inputs sequentially through LM Studio.

## Usage

``` r
lms_chat_batch(
  model,
  inputs,
  system_prompt = NULL,
  format = c("vector", "list", "data.frame"),
  host = "http://localhost:1234",
  simplify = TRUE,
  quiet = FALSE,
  ...
)
```

## Arguments

- model:

  Character. The loaded model name.

- inputs:

  Character vector. The prompts to process.

- system_prompt:

  Character. Optional system prompt.

- format:

  Character. Output format: "vector", "list", or "data.frame".

- host:

  Character. Server URL.

- simplify:

  Logical. If TRUE, parses outputs.

- quiet:

  Logical. Whether to suppress the progress bar.

- ...:

  Additional arguments passed to `lms_chat`.

## Value

The return type depends on the `format` argument:

- `"vector"`: A character vector of responses. This format is only
  supported if `simplify = TRUE` and `logprobs = FALSE`.

- `"list"`: A list where each element is the response corresponding to
  the provided input.

- `"data.frame"`: A data.frame containing `input` and `output` columns.
  If `logprobs = TRUE`, an additional list-column named `logprobs` is
  included.

## Details

This function calls
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
once for each element of `inputs`. It raises `rlmstudio_no_server`
itself, before the first call. It can raise `rlmstudio_api_error`
through
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md).

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
