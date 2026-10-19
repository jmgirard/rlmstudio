# M090: The curl echo fault is checked on Linux and reported to curl

**Status:** done (2026-10-18, PR #93 https://github.com/jmgirard/rlmstudio/pull/93).

**Goal:** A Linux run settles what the dry-run retry of `helper-mock-http.R` covers there, a test covers the retry after a curl error on every system, and the curl maintainers get a report of the `curl::curl_echo()` fault.

**Outcome:** `cairn/references/curl-echo-fault.md` records each dry-run try
of the held-port blocks on macOS and in `rocker/r-ver:4.6` (rows E1 to E7).
On Linux every held-port try ends with "Failed to create server", and the
time-limit block skips. A new block in `test-mock-http-helper.R` gives try 1
port 0 through `local_dry_run_ports()`, so curl's own transfer fails with
`curl_error_couldnt_connect`, and try 2 reads the request. It needs no
`curl::` call. The Linux comments state what the container showed. The
report, with a reproducer, is https://github.com/jeroen/curl/issues/459.

**Decisions:** none. Plan gate: a mock over a Linux socket setup, which
cannot give a curl error on one try only.

**Review:** Two passes. Return 1: `devtools::check()` warned on an undeclared
`curl::` import, fixed with port 0 and no DESCRIPTION change. 34 findings:
16 fixed (pinned ports, the comment, two report sentences, also edited on
issue 459 at the merge approval), 12 rejected, 4 follow-up (new row
"dry-run test comment gaps"), 2 noted. CI green, Windows included.
Graduated the row "curl echo fault follow-ups".
