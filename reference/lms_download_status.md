# Get the status of a download job

Get the status of a download job

## Usage

``` r
lms_download_status(job_id, host = "http://localhost:1234")
```

## Arguments

- job_id:

  Character. The unique identifier for the download job.

- host:

  Character. The host address of the local server. Defaults to
  "http://localhost:1234".

## Value

An object of class `lms_download_status` containing the download status.

## See also

[LM Studio Download Status
API](https://lmstudio.ai/docs/developer/rest/download-status)

## Examples

``` r
if (FALSE) { # \dontrun{
lms_server_start()

job_id <- lms_download("google/gemma-3-1b")
status <- lms_download_status(job_id)
print(status)
} # }
```
