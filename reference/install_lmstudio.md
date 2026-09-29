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

Invisibly returns `TRUE` upon successful completion. This function is
primarily utilized for its side effects of opening a web browser or
executing system installation commands.

## Details

If the headless installer exits with a status other than 0, the function
aborts. The message gives the exit code and quotes the installer output,
after "The installer said:". A byte that is not valid UTF-8 shows as
`<xx>`, its hex value. ANSI escape codes, such as color codes, cursor
codes, and terminal links, are removed, and each run of whitespace
becomes one space. A text longer than 1000 characters keeps at most its
last 1000 characters, after "…". Any other error of the install step,
such as a missing `curl`, aborts with "Headless installation failed."
and the error message.

## Examples

``` r
if (FALSE) { # \dontrun{
# Open your default web browser to the download page
install_lmstudio(method = "browser")

# Attempt automatic headless installation via the command line
install_lmstudio(method = "headless")
} # }
```
