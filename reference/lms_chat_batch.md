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
