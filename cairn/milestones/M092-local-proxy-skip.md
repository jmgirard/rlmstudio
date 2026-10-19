# M092: Requests to localhost, 127.0.0.1, and ::1 skip a set proxy

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP1
- **Resolves:** —
- **Surface tier:** user-facing — it changes where every package request to this machine goes when a proxy is set
- **Branch/PR:** m092-local-proxy-skip

## Goal

A package request to a `host` named `localhost`, `127.0.0.1`, or `::1` goes to that host directly, also when the proxy environment variables name a proxy.

## Scope

**In:** `lms_client()` in `R/chat.R` sets the curl option `noproxy` to the hostname for those three hostnames (D-044). New tests in `tests/testthat/test-proxy.R`. One `NEWS.md` entry.

**Out:** other loopback forms, such as `127.0.0.2` or `[::ffff:127.0.0.1]`. They keep libcurl's proxy rules (D-044 names the evidence that would reopen this). The no-server hint of D-042 keeps its own local set. The `free_port()` callers stay with the row "free_port held-port callers".

## Acceptance criteria

- [ ] AC1: With `http_proxy`, `https_proxy`, and `all_proxy` set to the address of a test proxy listener and `no_proxy` unset, a call to `lms_server_ready()` whose `host` names a test server by the hostname `localhost`, `LOCALHOST`, or `127.0.0.1` sends its request to that server. A test in `tests/testthat/test-proxy.R` asserts for each hostname that the test server recorded one request and the proxy listener recorded none. AC4 carries the claim to every request the package sends. (RB tripwire: ip-touching)
- [ ] AC2: The test of AC1 also runs for the hostname `[::1]`. Off CI, where the machine cannot listen on `::1`, that case skips with a message that says so. On CI it fails instead.
- [ ] AC3: With `http_proxy` set to the address of a test proxy listener, `lms_server_ready(host = "http://lmstudio.test:1234")` sends its request to that listener, and a test asserts that the listener recorded the URL `http://lmstudio.test:1234/api/v1/models`.
- [ ] AC4: `lms_client()` is the only place in `R/` that builds an httr2 request, and nothing in `R/` changes the URL of a request after it: `grep -rn 'httr2::request(' R/` prints one line, inside `lms_client()`, `grep -rn 'req_url(' R/` prints nothing, and `NAMESPACE` imports nothing from httr2.
- [ ] AC5: `NEWS.md`, under the development version, has one entry that says that a request to `localhost`, `127.0.0.1`, or `::1` no longer goes through a proxy that the proxy environment variables set, and that a request to any other host follows them as before.
- [ ] AC6: `devtools::check()` on the maintainer's machine gives 0 errors, 0 warnings, and 0 notes, `devtools::test()` passes, and the R-CMD-check jobs pass on the PR.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1
- AC4 → T4
- AC5 → T3
- AC6 → T4

## Tasks

- [x] T1: Write `tests/testthat/test-proxy.R`. Start two httpuv listeners in the test process, a test server and a proxy, and set the proxy variables with `withr::local_envvar()`. Call `lms_server_ready(host, timeout = 0.5)`, then run `httpuv::service()` to read the request that each listener holds. `req_perform()` blocks R, so neither listener answers during the call. One case for each hostname of AC1 and AC2, and the AC3 case. Do not go through `request_dry_run()`, which sets `noproxy = "*"` (`helper-mock-http.R:206`) and would hide the change. Before T2, the AC1 and AC2 cases must fail with the proxy listener holding the request, and the AC3 case must pass.
- [x] T2: In `lms_client()` (`R/chat.R:2697`), when the hostname from `host_address(host)`, in lower case, is `localhost`, `127.0.0.1`, or `::1`, add `httr2::req_options(noproxy = <hostname>)`. Probe that curl matches `LOCALHOST` and `[::1]` against that value. Update the roxygen block of `lms_client()`. Leave `no_server_hint()` unchanged.
- [x] T3: Add the `NEWS.md` entry of AC5.
- [x] T4: Run the AC4 greps, `devtools::document()`, `devtools::test()`, and `devtools::check()`. If LM Studio runs, also call `lms_server_ready()` with `http_proxy` set to a closed port, and log the result in one work-log line.

## Work log

- 2026-10-18: created by /milestone-plan.
- 2026-10-18: tier check: not run — work named at the question set.
- 2026-10-18: question set: which candidate to take — "proxy and local requests"; which hosts skip a set proxy — `localhost`, `127.0.0.1`, and `::1` (recorded as D-044).
- 2026-10-18: probe before planning: with `http_proxy` set to a closed port and `no_proxy` empty, httr2 requests to `localhost`, `LocalHost`, `127.0.0.1`, and `[::1]` all failed at the proxy port (curl 8.14.1, macOS). `no_proxy=localhost` did not cover `127.0.0.1`.
- 2026-10-18: collision check: absorbs the candidate row "proxy and local requests" in full. D-042 keeps its local set, and D-044 annotates it. M091 set `noproxy` in a test helper only. Inbox sweep: 0 open issues, 0 open PRs.
- 2026-10-18: criteria audit (full mode, Opus reader): 4 findings, all fixed. AC1 now asserts recorded requests, not a TRUE return, because an in-process listener cannot answer during `req_perform()`, and it names AC4 for the other requests. AC2 fails on CI instead of skipping. AC3 narrowed to the one tested host. AC4 gained the `req_url(` grep. AC6 names where the check runs.
- 2026-10-18: plan gate chose the three-name host set over every loopback address because users type these three; falsified by a user with another loopback host whose request goes to a proxy.
- 2026-10-18: plan gate chose `noproxy` set to the hostname over `noproxy = "*"` because a redirect to another host then keeps the user's proxy rules; falsified by a curl build that does not match `LOCALHOST` or `[::1]` against the hostname value.
- 2026-10-18: plan gate chose in-process httpuv listeners read after the call over a server in a second R process because callr is not in Suggests and adding it is a dependency change; falsified by a run where a listener does not get the request after the call times out.
- 2026-10-18: implement started on branch m092-local-proxy-skip; RB tripwire offer on AC1 (ip-touching): user chose to proceed without a brief.
- 2026-10-18: T1 done: `test-proxy.R` added. Before T2, the `localhost`, `LOCALHOST`, `127.0.0.1`, and `[::1]` cases each fail on both checks, with the test proxy holding the full URL; the other-host case passes. Each case takes about 0.2-0.3 s. The suite is red by design until T2.
- 2026-10-18: T2 done: `lms_client()` reads the hostname with `host_address()`, lowercases it, and sets `noproxy` to it for the three names. The option goes after `httr2::request(host)`, so a bad `host` still fails with the httr2 message. All 6 `test-proxy.R` cases pass, so curl matched `LOCALHOST` against `localhost` and `[::1]` against `::1`. `devtools::test()`: 3054 tests, 0 failed, 0 errors, 3 skipped. The "createTcpServer: address already in use" line comes from `test-mock-http-helper.R` alone, as before.
- 2026-10-18: T3 done: `NEWS.md` entry added at the top of the development version.
- 2026-10-18: T4: `grep -rn 'httr2::request(' R/` prints only `R/chat.R:2705`, `grep -rn 'req_url(' R/` prints nothing, and `NAMESPACE` has no httr2 line. `devtools::check()`: 0 errors, 0 warnings, 0 notes (2m 22s). Live probe: with LM Studio started on 1234 and `http_proxy`/`all_proxy` set to a closed port, `lms_server_ready()` for `localhost` and `127.0.0.1` returned TRUE and `list_models()` returned 7 rows, while a plain httr2 request failed at the proxy port. The server was stopped after.
- 2026-10-18: claim audit: 27 claims read, 3 corrected — NEWS.md, R/chat.R, tests/testthat/test-proxy.R. The NEWS "call failed" sentence now also names a proxy that forwards. The "other host" claims now say "starts at", and the `lms_client()` help names the redirect case. The httpuv comment names all three times the handler runs.
- 2026-10-18: the claim audit found that the `noproxy` option replaces the `no_proxy` variable for the whole request, so the plan's reason for `noproxy` set to the hostname holds for the proxy variables but not for `no_proxy` after a redirect. Kept the code, narrowed the prose, and added the candidate row "proxy redirect no_proxy". A test of a merged value needs a test server in a second process, because an in-process server cannot answer during the call.
- 2026-10-18: claim audit re-read of the 3 corrected claims: all accurate. Status set to review.
- 2026-10-18: review evidence pass: a planted `::1` bind failure showed the CI branch recording a failure and then a skip, since `fail()` does not stop the test. The case is now one if/else; the plant then gives a skip off CI and a failure with no skip on CI.
- 2026-10-18: lessons harvested: M004 (socket rules differ by system; httpuv must be in DESCRIPTION, which it is) and M087 (time test blocks on an idle machine, since each case waits 0.5 s).

## Decisions

## Review

- AC1 evidence (2026-10-18): `testthat::test_file("tests/testthat/test-proxy.R")` at 1f8b9bc: the subtests for `localhost`, `LOCALHOST`, and `127.0.0.1` pass, 2 expectations each (server recorded `/api/v1/models`, proxy recorded nothing). Before T2 the same subtests failed with the proxy holding the full URL (work log, T1). `lms_server_ready()` goes through `server_ready_request()` and `lms_client()`; AC4 carries the claim to the other requests.
- AC2 evidence (2026-10-18): the `[::1]` case passes on this machine, also with `CI=true` (0 failed, 0 skipped). A scratch copy that binds the test server to 203.0.113.1 gives a skip with CI unset and 1 failure with no skip with `CI=true`.
- AC3 evidence (2026-10-18): "a request to another host still goes to a set proxy" passes: the listener recorded `http://lmstudio.test:1234/api/v1/models`.
- AC4 evidence (2026-10-18): `grep -rn 'httr2::request(' R/` prints only `R/chat.R:2708`, inside `lms_client()`; `grep -rn 'req_url(' R/` prints nothing; `grep -c httr2 NAMESPACE` gives 0.
- AC5 evidence (2026-10-18): `NEWS.md` line 3, the first entry under `# rlmstudio (development version)`, names the three hostnames, the proxy variables, the old behavior, and that a request that starts at any other host follows the variables as before.
- Consistency gate (2026-10-18): `cairn_validate.py` all checks passed; `devtools::document()` no diff; README not touched; `pkgdown::check_pkgdown()` no problems; NEWS entry present; no new top-level file. No principle changed, so `cairn_impact` is skipped.
- spawned: diff-bug, blame-history, prior-review, ripple
- ripple #1: `cairn/references/lmstudio-api-surface.md:54-55` said `lms_client()` sets `Content-Type` and `Accept` only — fix now (marked as a record of when the note was written, corrected M092)
- ripple #2: the `request_dry_run()` comment in `helper-mock-http.R` gave the `noproxy = "*"` reason without the new `lms_client()` value — fix now (comment says the helper value replaces it)
