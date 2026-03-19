# Help the user install or update LM Studio

This function provides two methods for setting up LM Studio on your
system. The "browser" method opens the official download page for the LM
Studio desktop application (GUI). The "headless" method runs an
automated installation script to install the `llmster` daemon and CLI,
which is suitable for servers, containers, or users who prefer a
GUI-less environment.

## Usage

``` r
install_lmstudio(method = c("browser", "headless"))
```

## Arguments

- method:

  Character. Either "browser" (opens the GUI download page) or
  "headless" (installs the `llmster` daemon via script).

## Value

Returns `TRUE` invisibly upon successful completion. This function is
primarily called for its side effects of installing software or opening
a download page.

## Examples

``` r
if (FALSE) { # \dontrun{
# Open your default web browser to the download page
install_lmstudio(method = "browser")

# Attempt automatic headless installation via the command line
install_lmstudio(method = "headless")
} # }
```
