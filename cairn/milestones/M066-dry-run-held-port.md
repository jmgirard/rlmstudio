# M066: A test that reads a request survives a dry-run port that another program holds

- **Status:** review
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

- [x] AC1: If another listener holds the first dry-run port on 127.0.0.1,
      `request_target()` still returns the sent method, path, and body. That
      function is in `tests/testthat/helper-mock-http.R`. A test in
      `tests/testthat/test-mock-http-helper.R` holds such a listener.
- [x] AC2: If every try lands on a held port, the shared dry-run helper stops
      with a message. The message says that the dry run received no request.
      It names another program on the port as the likely cause. It replaces
      "argument 'x' must be a raw vector". A test in
      `tests/testthat/test-mock-http-helper.R` asserts that message.
- [x] AC3: Each line that `grep -rn "req_dry_run(" tests/testthat` returns is
      a comment or the one call inside the shared dry-run helper. That helper
      is in `tests/testthat/helper-mock-http.R`.
- [x] AC4: `devtools::test()` reports 0 failed and 0 errors.
      `devtools::check()` reports 0 errors, 0 warnings, and 0 notes.

## Coverage

- AC1 → T1, T2, T5, T6
- AC2 → T1, T2
- AC3 → T3
- AC4 → T4, T7

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
- [x] T3: Route the five local dry-run reads through the helper. They are
      `sent_messages()` in `test-arg-guards.R`, `sent_json()` in
      `test-ttl.R`, and the helpers in `test-embed.R`, `test-chat-schema.R`,
      and `test-token.R`. Run the AC3 grep.
- [x] T4: In a scratch copy, remove the retry and see the AC1 test go red.
      Then restore it. Run `devtools::test()` and `devtools::check()`.
- [x] T5: Write an AC1 test first for a listener that never replies. Hold
      the first port with `httpuv::startServer("127.0.0.1", port)` and a
      handler that returns `NULL`. Run it against the current helper and
      record the failure identity.
- [x] T6: In `request_dry_run()`, give each try a 5-second timeout with
      `httr2::req_timeout()`. Retry on any error of class `curl_error`, as
      well as on the bind error. Update the helper comment.
- [x] T7: In a scratch copy, remove the `curl_error` retry and see the T5
      test go red. Then run `devtools::test()` and `devtools::check()`.

## Work log

- 2026-09-30: created by /milestone-plan, from the [high] candidate row on the test error at `rawToChar(out$body)`. A scratch probe reproduced the error with a listener on 127.0.0.1 at the dry-run port.
- 2026-09-30: criteria audit (reduced mode, fresh Opus reader) found one issue. AC1 named how the test mocks the port, an instrument detail. The sentence moved to T1. AC2 to AC4 had no finding.
- 2026-09-30: plan gate chose a retry in one shared helper over a mock of curl's port picker around every dry run. The mock ties each request read to a curl internal, and a race stays. Falsified by a dry-run failure that retries do not clear.
- 2026-09-30: implement started on branch m066-dry-run-held-port. A probe on macOS reproduced the empty dry run with a mocked `find_port`. Docker was not running, so no Linux probe ran.
- 2026-09-30: implement question gate chose a retry on httpuv's bind error too (see Decisions).
- 2026-09-30: T1 done. Before the fix, the held-port test got no method, path, or body after 1 try. The all-tries test got "argument 'x' must be a raw vector".
- 2026-09-30: T2 done. `request_dry_run()` in `helper-mock-http.R` retries up to 5 tries, and `request_target()` and `request_body_text()` call it. A third test holds the first port on all addresses, so the bind-error retry runs on macOS too. `devtools::test()`: 0 failed, 0 errors, 3 skipped.
- 2026-09-30: T3 done. The five local reads call `request_dry_run()` and drop their own `require_httpuv()`. The AC3 grep returns 4 comment lines and the one call in the helper. The first `devtools::test()` gave 0 failed and 1 error, but the summary kept no test name or message. Four later runs gave 0 failed and 0 errors. Three of them ran in a script that prints the file, test, and message of each error, and it printed none.
- 2026-09-30: T4 done. In a scratch copy with the helper set to 1 try, both read tests stopped with the AC2 message. The all-tries test counted 1 try in place of 5. The repo copy did not change. `devtools::check()` with the API token: 0 errors, 0 warnings, 0 notes.
- 2026-09-30: claim audit: not owed — internal tier
- 2026-09-30: all tasks done. Status set to review. This is the unnamed-error candidate row.
- 2026-09-30: review started. AC1 to AC3 verified. AC4 run, the document() check, and three reviewers are still running (checkpoint, review not done).
- 2026-09-30: review return 1 (defect). AC1 fails. A listener on 127.0.0.1 that resets the connection, sends a non-HTTP banner, or never replies makes `request_target()` stop or hang with no retry. Status set to in-progress. See the Review section for the probe and the repair.
- 2026-09-30: implement resumed. Minor amendment: added T5 to T7 for the review return, with Coverage lines. A probe showed that an httpuv handler that returns `NULL` never replies, so the T5 test needs no new package. Reset, banner, and timeout errors all have class `curl_error`.
- 2026-09-30: T5 done. Against the old helper, the never-replies test gave no result after 20 seconds, and an alarm ended the run.
- 2026-09-30: T6 done. `request_dry_run()` sets a 5-second timeout on each try and retries on any `curl_error`. The never-replies test passes with 2 tries. A probe with the reset and banner listeners got POST with 2 tries each. `devtools::test()`: 0 failed, 0 errors, 3 skipped.
- 2026-09-30: T7 done. In a scratch copy without the `curl_error` retry, the never-replies test stopped on try 1 with "Timeout was reached [127.0.0.1]". The repo copy did not change. `devtools::check()` with the API token: 0 errors, 0 warnings, 0 notes.
- 2026-09-30: claim audit: not owed, internal tier
- 2026-09-30: all tasks done again after review return 1. Status set to review.
- 2026-09-30: second review pass started. AC1 to AC3 verified again. The check and one reviewer are still running (checkpoint, review not done).

## Decisions

- 2026-09-30 (implement gate): If the dry run fails with httpuv's "Failed to create server" error, the shared dry-run helper also retries. That retry uses the same 5 tries and ends with the AC2 message. Linux, and probably Windows, is expected to refuse a bind to 0.0.0.0 on a port that 127.0.0.1 holds. On those systems, the forced-port tests get that error in place of an empty result. The helper catches no other error.
- 2026-09-30 (review return): this entry narrows the one above. The shared dry-run helper also retries on any error of class `curl_error`. The dry run sends to the echo port alone, so a curl error means that the connection to that port failed. Each try gets a 5-second timeout, so a program that never replies ends the try. Five tries then fit inside the 30-second limit of `request_body_text()`. The helper still re-raises every other error.

## Review

- AC1 evidence (2026-09-30): `test_file("test-mock-http-helper.R")` passed. The held-port test and the bind-error test got POST, the path, and the body, with 2 tries each. In a scratch copy with 1 try, both tests stopped with the AC2 message, so the retry is what makes them pass.
- AC2 evidence (2026-09-30): the all-tries test passed with 5 tries. It asserts "received no request", "another program", and no "must be a raw vector". In the 1-try scratch copy, the stop message read "The dry run received no request in 1 tries. Another program probably listens on 127.0.0.1 at the port that curl::curl_echo() picked."
- AC3 evidence (2026-09-30): the grep returned 5 lines. Four are comments at `helper-mock-http.R` lines 88, 102, 177, and 179. One is the call at line 192, inside `request_dry_run()`.
- AC4 evidence (2026-09-30): `devtools::test()` gave 0 failed, 0 errors, 3 skipped (no local LM Studio server), 19383 passed. `devtools::check()` with the API token gave 0 errors, 0 warnings, 0 notes.
- Gate (2026-09-30): `cairn_validate.py` passed every check. `devtools::document()` left no diff. The branch changes nothing in `R/`, `man/`, `NEWS.md`, or the README. The repo has no pkgdown site. No changelog entry is owed.
- AC1 fails (2026-09-30): the diff-bug reviewer found that a listener on the held port that is not an HTTP server defeats the retry. A review probe held the first port with a Python listener that closes each connection. `request_target()` stopped on try 1 with "Failure when receiving data from the peer [127.0.0.1]: Recv failure: Connection reset by peer". The reviewer saw "Received HTTP/0.9 when not allowed" from a listener that sends an SSH banner. A listener that never replies makes `request_target()` wait with no limit. AC1 names any listener, so AC1 fails, and its tick is removed.
- Repair found by probe (2026-09-30): with `httr2::req_timeout(3)` on the request, the silent listener gives "Timeout was reached [127.0.0.1]" after 3 seconds. Each of the three cases is then a curl error that names `[127.0.0.1]`, the echo host. A retry on each dry-run error whose message names that host covers them. The error source decides that rule, not a list of known cases. So this is a defect return and not a criterion amendment.
- Findings not yet triaged (2026-09-30). They go to the next merge gate, most severe first.
  - Diff-bug (2): a silent listener hangs `request_target()` and the five local reads. In a probe, the 30 s limit in `request_body_text()` fired inside an httpuv callback. That halted Rscript.
  - Diff-bug (3): no run on Windows covers the forced-port tests. The `tries$n == 2L` result there is unverified.
  - Diff-bug (4): each failed bind prints "createTcpServer: address already in use" to stderr.
  - Diff-bug nits: `request_body_text()` calls `require_httpuv()` twice. With `tries = 1`, the stop message reads "1 tries".
  - History (1): each retry adds one `sample()` draw in curl's `find_port()`. The shared port helpers were made seed-safe on purpose.
  - History (2): the new tests mock curl's private `find_port`. A curl rename makes them fail loudly.
  - History (3): the helper matches "Failed to create server" exactly. It re-raises a reworded httpuv error.
  - History (4): the same double `require_httpuv()` call.
  - Prior-review: no conflict with earlier reviews. It noted that the new test names a local variable `message`.

Second pass (after review return 1):

- AC1 evidence (2026-09-30): `devtools::test(filter = "mock-http-helper")` gave 0 failed, 0 errors. The held-port, bind-error, and never-replies tests passed with 2 tries each. A probe held the first port with a Python listener of each kind the first pass named. A reset listener, an SSH-banner listener, and a silent listener each gave POST, `/v1/models/load`, and the body, with 2 tries. The silent case took 5 s. With `tries` set to 1 in the probe, all three stopped with the AC2 message, so the retry is what makes them pass.
- AC2 evidence (2026-09-30): in the same run, the all-tries test passed its 5 expectations. It asserts "received no request", "another program", no "must be a raw vector", and 5 tries. The 1-try probe above printed the full message, which names another program on 127.0.0.1 as the likely cause.
- AC3 evidence (2026-09-30): the grep returned 5 lines. Four are comments at `helper-mock-http.R` lines 88, 102, 177, and 179. One is the call at line 199, inside `request_dry_run()`.
