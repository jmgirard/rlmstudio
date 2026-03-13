# Get the absolute path to the LMS executable

Locates the LM Studio CLI (`lms`) on your system. It checks the
`RLMSTUDIO_LMS_PATH` environment variable first, then the system `PATH`,
and finally common installation directories.

## Usage

``` r
lms_path()
```

## Value

A character string containing the absolute path to the executable.

## Examples

``` r
if (FALSE) { # \dontrun{
lms_path()
} # }
```
