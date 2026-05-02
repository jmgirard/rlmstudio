# Get the absolute path to the LMS executable

Locates the LM Studio CLI (`lms`) on your system. It checks the
`RLMSTUDIO_LMS_PATH` environment variable first, then the system `PATH`,
and finally common installation directories.

## Usage

``` r
lms_path()
```

## Value

A character string specifying the absolute file path to the LM Studio
executable (`lms`) on the user's system.

## Examples

``` r
if (FALSE) { # \dontrun{
lms_path()
} # }
```
