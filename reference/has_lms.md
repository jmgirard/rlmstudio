# Check if LM Studio CLI is installed

Uses the same lookup as
[`lms_path()`](https://jmgirard.github.io/rlmstudio/reference/lms_path.md):
the `RLMSTUDIO_LMS_PATH` environment variable, then the system `PATH`,
then common installation directories.

## Usage

``` r
has_lms()
```

## Value

A logical scalar: `TRUE` if
[`lms_path()`](https://jmgirard.github.io/rlmstudio/reference/lms_path.md)
finds the `lms` executable, and `FALSE` if it aborts.

## Examples

``` r
if (FALSE) { # \dontrun{
has_lms()
} # }
```
