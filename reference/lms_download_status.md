# Get the status of a download job

Get the status of a download job

## Usage

``` r
lms_download_status(job_id, host = "http://localhost:1234", token = NULL)
```

## Arguments

- job_id:

  Character. The unique identifier for the download job.

- host:

  Character. The host address of the local server. Defaults to
  "http://localhost:1234".

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

An object of class `lms_download_status` containing the download status.

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
