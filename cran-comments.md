## Resubmission

This resubmission fixes the test error of the Debian incoming pretest. A test matched the full libcurl message for a URL with no host, and that wording differs between libcurl versions. The test now matches only the part that all versions share.

## R CMD check results

0 errors | 0 warnings | 0 notes

## Test environments

* local macOS 27.0.1, R 4.6.1
* GitHub Actions: macOS (release), Windows (release), Ubuntu (release, oldrel-1)
* win-builder (devel and release)

## Reverse dependencies

There are currently no downstream dependencies for this package.
