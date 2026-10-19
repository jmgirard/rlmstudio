# The curl echo fault and the dry-run retry, on macOS and Linux (M090)

**Provenance.** Ingested 2026-10-18 by M090. A trace script ran over
`tests/testthat/test-mock-http-helper.R` on macOS and in the
`rocker/r-ver:4.6` Docker image. M090 also read `R/echo.R` in `jeroen/curl`.
Pagination: —.
Extraction: first-hand record, nothing to re-verify against — observed 2026-10-18.

**Scope.** This page records what each dry-run try of the held-port tests
ended with on two systems. It also holds the report of the fault to the curl
maintainers. It is not a source summary. It is a reference and not an
authority: status lives in `ROADMAP.md`, decisions in `DECISIONS.md`, and
architecture in `DESIGN.md`.

**Evidence snapshot.**

- macOS run: R 4.6.1, darwin23, curl 8.0.0, libcurl 8.14.1, httpuv 1.6.17 — observed 2026-10-18.
- Linux run: `rocker/r-ver:4.6` (Ubuntu 24.04.5), R 4.6.1, curl 8.1.0, libcurl 8.5.0, httpuv 1.6.17 — observed 2026-10-18.
- The container clock read 2026-10-19 UTC. Its packages came from P3M.

## The fault

`curl::curl_echo()` starts its echo server with
`httpuv::startServer("0.0.0.0", port, ...)` and sends the request to
`http://127.0.0.1:<port>`. A program that listens on 127.0.0.1 alone at that
port does not stop `find_port()`, which binds all addresses. macOS lets the
0.0.0.0 bind share such a port, so the request goes to the other program.
Linux refuses the bind, so the dry run stops with httpuv's "Failed to create
server".

## How the runs were made

A trace script, kept outside the repo, ran each `test_that()` block that
calls `local_dry_run_ports(`. Before M090 there were 5 such blocks. The
script also ran the URL-with-space block. It ran the blocks one at a time
through `testthat::test_file(desc = )` with `NOT_CRAN=true`. It replaced
`httr2::req_dry_run()` with a wrapper that logs one line for each call. A
result with a method logs "request read". A result with no method logs
"empty result". A condition logs its classes and message. The helper code
did not change. In the URL-with-space block, try 1 is the test's own direct
call of `req_dry_run()`, and tries 2 to 6 are the 5 tries of the helper.

## Results

| # | Block | macOS | Linux container |
|---|---|---|---|
| E1 | another program holds the first dry-run port | try 1 empty result, try 2 request read | try 1 "Failed to create server", try 2 request read |
| E2 | the echo server cannot bind the first port | try 1 "Failed to create server", try 2 request read | try 1 "Failed to create server", try 2 request read |
| E3 | the program on the first dry-run port never replies | try 1 `curl_error_operation_timedout`: "Timeout was reached [127.0.0.1]: Operation timed out after 5000 milliseconds with 0 bytes received", try 2 request read | try 1 "Failed to create server", try 2 request read |
| E4 | every try lands on a held port | tries 1 to 5 empty result | tries 1 to 5 "Failed to create server" |
| E5 | the request itself is at fault (URL with a space) | tries 1 to 6 `curl_error_url_malformat`: "URL using bad/illegal format or missing URL: URL rejected: Malformed input to a URL function" | tries 1 to 6 `curl_error_out_of_memory`: "Out of memory" |
| E6 | `request_body_text()` spreads its time limit | tries 1 to 5 `curl_error_operation_timedout`: "Timeout was reached [127.0.0.1]: Operation timed out after 500 milliseconds with 0 bytes received" | skipped before any try: "The echo server cannot bind a port that 127.0.0.1 holds here." |

"Failed to create server" has the classes `simpleError`, `error`, and
`condition` on both systems.

## Disposition

On Linux, every held-port block passes through the "Failed to create
server" retry (E1 to E4). So before M090, no Linux run covered a
`curl_error` on one try and a read on the next. E5 reaches the `curl_error`
branch on Linux, but every try fails there. The M090 test for the retry
after a curl error closes that gap.
