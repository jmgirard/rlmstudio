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
| E7 | the first dry run ends with a curl error (added by M090, try 1 on port 0) | try 1 `curl_error_couldnt_connect`: "Could not connect to server [127.0.0.1]: Failed to connect to 127.0.0.1 port 0 after 0 ms: Could not connect to server", try 2 request read | try 1 `curl_error_couldnt_connect`: "Couldn't connect to server [127.0.0.1]: Failed to connect to 127.0.0.1 port 0 after 0 ms: Couldn't connect to server", try 2 request read |

E7 ran after the M090 review return, on the same two systems. It calls
`local_dry_run_ports(`, so with it the file has 6 such blocks. With E7, the
whole file gave 41 passed, 1 skipped (E6), and 0 failed in the container.

"Failed to create server" has the classes `simpleError`, `error`, and
`condition` on both systems.

## The source lines

At `jeroen/curl` commit `d4f60d67d38166c900f8cd9cf658cfd28340a425`
(2026-10-14), `R/echo.R` line 62 binds the echo server with
`httpuv::startServer("0.0.0.0", port, ...)`. Lines 84 and 94 send the
request to `http://127.0.0.1:<port>`. In `src/findport.c`, lines 52 and 63
probe each port on `INADDR_ANY` with `SO_REUSEADDR`.

## The reproducer and its runs

```r
library(curl)

# Another program listens on 127.0.0.1 alone at a port.
port <- httpuv::randomPort()
other <- httpuv::startServer(
  "127.0.0.1", port,
  list(call = function(req) list(status = 200L, headers = list(), body = ""))
)

# find_port() still reports the port as free.
curl:::find_port(port)

# curl_echo() binds 0.0.0.0 at that port and sends the request to 127.0.0.1.
h <- new_handle(url = "http://localhost/hello", postfields = "abc")
res <- curl_echo(h, port = port)
str(res)

httpuv::stopServer(other)
packageVersion("curl")
curl_version()$version
```

macOS 27.0.1 (arm64), R 4.6.1, curl 8.0.0, libcurl 8.14.1, run 2026-10-18.
`find_port(port)` returned the held port, and `curl_echo()` returned a list
with `url` alone, so the result has no method, path, or body:

```
> str(res)
List of 1
 $ url: chr "http://localhost/hello"
```

In the Linux container (curl 8.1.0, libcurl 8.5.0), run 2026-10-18,
`find_port(port)` returned `NULL`, and `curl_echo()` stopped with
"Failed to create server".

## The report

Filed 2026-10-18 as https://github.com/jeroen/curl/issues/459. The text
below corrects two sentences of the filed text (M090 review, diff-bug
findings 6 and 7). The filed text gave a held port as the cause of the empty
results, and no run observed that cause. It also did not limit the
`find_port()` sentence to macOS. On 2026-10-18 the issue body was edited to
the text below.

Title: `curl_echo() can send the request to another program on macOS`

````markdown
`curl_echo()` starts its server on `0.0.0.0` ([R/echo.R#L62](https://github.com/jeroen/curl/blob/d4f60d67d38166c900f8cd9cf658cfd28340a425/R/echo.R#L62)) but sends the request to `127.0.0.1` ([L84](https://github.com/jeroen/curl/blob/d4f60d67d38166c900f8cd9cf658cfd28340a425/R/echo.R#L84), [L94](https://github.com/jeroen/curl/blob/d4f60d67d38166c900f8cd9cf658cfd28340a425/R/echo.R#L94)). On macOS, a bind to `0.0.0.0` can share a port that another program holds on `127.0.0.1` alone. The request then goes to that other program, and `curl_echo()` returns a result with no method, path, or body. `find_port()` probes on `INADDR_ANY` with `SO_REUSEADDR` ([src/findport.c#L52](https://github.com/jeroen/curl/blob/d4f60d67d38166c900f8cd9cf658cfd28340a425/src/findport.c#L52)), so on macOS it reports such a port as free.

We found this while looking into a package test suite in which `httr2::req_dry_run()` now and then returned a result with no body. The reprex below shows one way to get such a result.

Reprex (macOS 27.0.1 arm64, R 4.6.1, curl 8.0.0, libcurl 8.14.1):

```r
library(curl)

# Another program listens on 127.0.0.1 alone at a port.
port <- httpuv::randomPort()
other <- httpuv::startServer(
  "127.0.0.1", port,
  list(call = function(req) list(status = 200L, headers = list(), body = ""))
)

# find_port() still reports the port as free.
curl:::find_port(port)

# curl_echo() binds 0.0.0.0 at that port and sends the request to 127.0.0.1.
h <- new_handle(url = "http://localhost/hello", postfields = "abc")
res <- curl_echo(h, port = port)
str(res)
#> List of 1
#>  $ url: chr "http://localhost/hello"

httpuv::stopServer(other)
```

On Linux (Ubuntu 24.04, curl 8.1.0, libcurl 8.5.0), `find_port(port)` returns `NULL` in the same script. There `curl_echo()` stops with "Failed to create server", so we see the problem on macOS and not on Linux.

A possible fix is to bind the echo server to `127.0.0.1`, the address it sends to, and to probe `127.0.0.1` in `find_port()`.
````

## Disposition

On Linux, every held-port block passes through the "Failed to create
server" retry (E1 to E4). So before M090, no Linux run covered a
`curl_error` on one try and a read on the next. E5 reaches the `curl_error`
branch on Linux, but every try fails there. The M090 test for the retry
after a curl error closes that gap.
