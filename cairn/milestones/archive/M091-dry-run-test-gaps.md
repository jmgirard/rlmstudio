# M091: Test dry runs skip a set proxy, and two helper comments match each system

**Status:** done (2026-10-18, PR #94 https://github.com/jmgirard/rlmstudio/pull/94).

**Goal:** The test dry runs of `helper-mock-http.R` reach the echo server when a proxy is set, and the comments of two test helpers state what happens on macOS and on Linux.

**Outcome:** `request_dry_run()` sets `httr2::req_options(noproxy = "*")`,
so a set `http_proxy` or `all_proxy` no longer sends each dry run to the
proxy. A new block in `test-mock-http-helper.R` sets both, runs a control dry
run without `noproxy` that must fail to connect, and reads the request in 1
try. The `free_port()` comment, the `serverSocket()` comment of
`helper-ports.R`, and the never-replies comment state the macOS and Linux
results (row E3 of `cairn/references/curl-echo-fault.md`). The URL-with-space
test sends its direct dry run with `noproxy` too.

**Decisions:** none. Plan gate: the curl option over a `withr` `no_proxy`
setting inside the helper.

**Review:** Four-lens fan-out, 17 findings: 6 fixed (control dry run, three
comments, the URL test), 5 follow-up (new row "free_port held-port callers"),
6 rejected. CI red once on Windows only: there the control's connect times
out at 2 s, so it now accepts either connection error. CI green after.
Graduated the row "dry-run test comment gaps".
