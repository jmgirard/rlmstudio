# M092: Requests to localhost, 127.0.0.1, and ::1 skip a set proxy

**Status:** done (2026-10-19, PR #95 https://github.com/jmgirard/rlmstudio/pull/95).

**Goal:** A package request to a `host` named `localhost`, `127.0.0.1`, or `::1` goes to that host directly, also when the proxy environment variables name a proxy.

**Outcome:** `lms_client()` reads the hostname with `host_address()`,
lowercases it, and for `localhost`, `127.0.0.1`, or `::1` sets curl's
`noproxy` option to that hostname. Other hosts keep libcurl's proxy rules
(D-044). The option replaces `no_proxy` for the whole request, so a redirect
from those hosts loses the user's `no_proxy` (D-045). New
`tests/testthat/test-proxy.R` runs a test server and a test proxy with httpuv
in the test process and reads what each recorded after the call times out.
The `localhost` server also listens on `::1`, and the `[::1]` case fails on CI
instead of skipping. One NEWS entry.

**Decisions:** none milestone-local. D-044 (host set), D-045 (redirect case).

**Review:** Four-lens fan-out, 17 findings: 7 fixed (a `::1` listener for
the Windows `localhost` case, recorder retries and a proxy start check, a
work-log figure, a reference note, a helper comment), 1 follow-up (new row
"proxy redirect no_proxy"), 9 rejected. Claim audit corrected 3 passages.
CI green on all jobs. Graduated the row "proxy and local requests". Extended
the M004 socket lesson.
