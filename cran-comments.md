This release fixes the test errors in the CRAN checks of 0.3.0 on r-devel-linux-x86_64-debian-clang, r-devel-linux-x86_64-debian-gcc, and r-patched-linux-x86_64. The tests no longer expect one libcurl version's wording of a curl error.

## R CMD check results

0 errors | 0 warnings | 0 notes

## Test environments

* local macOS 27.2.1, R 4.6.2
* GitHub Actions: macOS (release), Windows (release), Ubuntu (release, oldrel-1)
* Debian testing with libcurl 8.23.0 (the affected tests only)
* win-builder (devel and release)

## Reverse dependencies

There are currently no downstream dependencies for this package.
