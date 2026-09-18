# Check if the installed LM Studio CLI meets the minimum requirement

Check if the installed LM Studio CLI meets the minimum requirement

## Usage

``` r
check_lms_version(min_version = "0.4.0")
```

## Arguments

- min_version:

  Character string of the required version. Default is "0.4.0".

## Value

A logical scalar: `TRUE` if the LM Studio CLI version meets or exceeds
the specified `min_version`, and `FALSE` otherwise, including when
[`lms_path()`](https://jmgirard.github.io/rlmstudio/reference/lms_path.md)
does not find the CLI.

## Examples

``` r
if (FALSE) { # \dontrun{
check_lms_version("0.4.0")
} # }
```
