# Load a model via REST API

Load a model via REST API

## Usage

``` r
lms_load(
  model,
  context_length = NULL,
  eval_batch_size = NULL,
  flash_attention = NULL,
  num_experts = NULL,
  offload_kv_cache_to_gpu = NULL,
  echo_load_config = FALSE,
  force = FALSE,
  host = "http://localhost:1234",
  ...
)
```

## Arguments

- model:

  Character. Unique identifier for the model to load.

- context_length:

  Integer. Maximum number of tokens that the model will consider.

- eval_batch_size:

  Integer. Number of input tokens to process together in a single batch
  during evaluation.

- flash_attention:

  Logical. Whether to optimize attention computation.

- num_experts:

  Integer. Number of experts to use during inference for MoE models.

- offload_kv_cache_to_gpu:

  Logical. Whether KV cache is offloaded to GPU memory.

- echo_load_config:

  Logical. If `TRUE`, echoes the final load configuration in the
  response.

- force:

  Logical. If `TRUE`, bypasses the check for currently loaded models and
  requests a new instance from the server. Note that this does not
  overwrite or replace the existing model; it loads a second concurrent
  instance into VRAM. Defaults to `FALSE`.

- host:

  Character. The host address of the local server. Defaults to
  "http://localhost:1234".

- ...:

  Additional arguments passed to the API request body (useful for future
  API parameters).

## Value

Invisibly returns a character string of the loaded model identifier upon
success. If `echo_load_config = TRUE`, it instead invisibly returns a
list containing the model's detailed load configuration.

## See also

[LM Studio Load Model API](https://lmstudio.ai/docs/developer/rest/load)

## Examples

``` r
if (FALSE) { # \dontrun{
lms_server_start()
lms_download("google/gemma-3-1b")

# Load a model with default settings
lms_load("google/gemma-3-1b")

# Load a model with custom context length and flash attention enabled
lms_load("google/gemma-3-1b", context_length = 8192, flash_attention = TRUE)
} # }
```
