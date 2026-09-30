# M066: A test that reads a request survives a dry-run port that another program holds

- **Status:** in-progress
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — the deliverable is test helper code, which no package user runs
- **Branch/PR:** m066-dry-run-held-port

## Goal

If another program holds the dry-run port on 127.0.0.1, a test that reads
what a request sends still passes.

## Scope

**In:** The cause, from probes on 2026-09-30. httr2 1.3.0 `req_dry_run()`
calls `curl::curl_echo()` (curl 8.0.0). That function picks a port with
`find_port()`. It starts an httpuv echo server on 0.0.0.0 at that port. It
sends the request to 127.0.0.1 at that port. Another program can listen on
127.0.0.1 alone at that port. Then `find_port()` still returns the port, and
the httpuv bind succeeds. The request reaches the other program, and
`curl_echo()` returns a list that holds only `url`. `rawToChar(out$body)`
then fails with "argument 'x' must be a raw vector". A mock of `find_port`
in the curl namespace sets the port that `req_dry_run()` uses. The fix is one
shared dry-run helper. If the dry run saw no request, the helper tries again.
All dry-run reads in the tests go through it.

**Out:** A candidate row holds the pass-count difference of two clean runs
and the three earlier errors with no message. If they recur after this
milestone, promote that row. A report of the curl fault to its maintainers is
a candidate row. The package code does not change.

## Acceptance criteria

- [ ] AC1: If another listener holds the first dry-run port on 127.0.0.1,
      `request_target()` still returns the sent method, path, and body. That
      function is in `tests/testthat/helper-mock-http.R`. A test in
      `tests/testthat/test-mock-http-helper.R` holds such a listener.
- [ ] AC2: If every try lands on a held port, the shared dry-run helper stops
      with a message. The message says that the dry run received no request.
      It names another program on the port as the likely cause. It replaces
      "argument 'x' must be a raw vector". A test in
      `tests/testthat/test-mock-http-helper.R` asserts that message.
- [ ] AC3: Each line that `grep -rn "req_dry_run(" tests/testthat` returns is
      a comment or the one call inside the shared dry-run helper. That helper
      is in `tests/testthat/helper-mock-http.R`.
- [ ] AC4: `devtools::test()` reports 0 failed and 0 errors.
      `devtools::check()` reports 0 errors, 0 warnings, and 0 notes.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T3
- AC4 → T4

## Tasks

- [x] T1: Write the AC1 and AC2 tests first. Hold a loopback listener with
      `httpuv::startServer("127.0.0.1", port)` on a port from `free_port()`.
      Mock curl's `find_port` so that the first try, or every try, gets the
      held port. Run the tests against the current helper and record the
      failure identity.
- [x] T2: Add the shared dry-run helper to `helper-mock-http.R`. It calls
      `httr2::req_dry_run()`. If the result has no `method`, it tries again.
      After 5 tries, it stops with the AC2 message. Route `request_target()`
      and `request_body_text()` through it. The comment states the cause from
      the probe.
- [ ] T3: Route the five local dry-run reads through the helper. They are
      `sent_messages()` in `test-arg-guards.R`, `sent_json()` in
      `test-ttl.R`, and the helpers in `test-embed.R`, `test-chat-schema.R`,
      and `test-token.R`. Run the AC3 grep.
- [ ] T4: In a scratch copy, remove the retry and see the AC1 test go red.
      Then restore it. Run `devtools::test()` and `devtools::check()`.

## Work log

- 2026-09-30: created by /milestone-plan, from the [high] candidate row on the test error at `rawToChar(out$body)`. A scratch probe reproduced the error with a listener on 127.0.0.1 at the dry-run port.
- 2026-09-30: criteria audit (reduced mode, fresh Opus reader) found one issue. AC1 named how the test mocks the port, an instrument detail. The sentence moved to T1. AC2 to AC4 had no finding.
- 2026-09-30: plan gate chose a retry in one shared helper over a mock of curl's port picker around every dry run. The mock ties each request read to a curl internal, and a race stays. Falsified by a dry-run failure that retries do not clear.
- 2026-09-30: implement started on branch m066-dry-run-held-port. A probe on macOS reproduced the empty dry run with a mocked `find_port`. Docker was not running, so no Linux probe ran.
- 2026-09-30: implement question gate chose a retry on httpuv's bind error too (see Decisions).
- 2026-09-30: T1 done. Before the fix, the held-port test got no method, path, or body after 1 try, and the all-tries test got "argument 'x' must be a raw vector".
- 2026-09-30: T2 done. `request_dry_run()` in `helper-mock-http.R` retries up to 5 tries, and `request_target()` and `request_body_text()` call it. A third test holds the first port on all addresses, so the bind-error retry runs on macOS too. `devtools::test()`: 0 failed, 0 errors, 3 skipped.

## Decisions

- 2026-09-30 (implement gate): If the dry run fails with httpuv's "Failed to create server" error, the shared dry-run helper also retries. That retry uses the same 5 tries and ends with the AC2 message. On Linux, and likely on Windows, the operating system is expected to refuse the echo server's bind to 0.0.0.0 on a port that 127.0.0.1 holds. There, the forced-port tests get that error in place of an empty result. The helper catches no other error.

## Review
