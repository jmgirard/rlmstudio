# Download a model via REST API

Download a model via REST API

## Usage

``` r
lms_download(model, quantization = NULL, host = "http://localhost:1234", ...)
```

## Arguments

- model:

  Character. The model to download. Accepts model catalog identifiers
  (e.g., "openai/gpt-oss-20b") and exact Hugging Face links.

- quantization:

  Character. Optional. Quantization level of the model to download
  (e.g., "Q4_K_M"). Only supported for Hugging Face links.

- host:

  Character. The host address of the local server. Defaults to
  "http://localhost:1234".

- ...:

  Additional arguments passed to the request.

## Value

A character string containing the download `job_id`, or
`"already_downloaded"` if already downloaded.
