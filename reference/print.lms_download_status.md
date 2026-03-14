# Print method for LM Studio download status

Print method for LM Studio download status

## Usage

``` r
# S3 method for class 'lms_download_status'
print(x, ...)
```

## Arguments

- x:

  An object of class `lms_download_status`.

- ...:

  Additional arguments passed to print.

## Examples

``` r
if (FALSE) { # \dontrun{
lms_server_start()

job_id <- lms_download("google/gemma-3-1b")
status <- lms_download_status(job_id)
print(status)
} # }
```
