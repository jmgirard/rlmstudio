# M092: Requests to localhost, 127.0.0.1, and ::1 skip a set proxy

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP1
- **Resolves:** —
- **Surface tier:** user-facing — it changes where every package request to this machine goes when a proxy is set
- **Branch/PR:** —

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

- [ ] T1: Write `tests/testthat/test-proxy.R`. Start two httpuv listeners in the test process, a test server and a proxy, and set the proxy variables with `withr::local_envvar()`. Call `lms_server_ready(host, timeout = 0.5)`, then run `httpuv::service()` to read the request that each listener holds. `req_perform()` blocks R, so neither listener answers during the call. One case for each hostname of AC1 and AC2, and the AC3 case. Do not go through `request_dry_run()`, which sets `noproxy = "*"` (`helper-mock-http.R:206`) and would hide the change. Before T2, the AC1 and AC2 cases must fail with the proxy listener holding the request, and the AC3 case must pass.
- [ ] T2: In `lms_client()` (`R/chat.R:2697`), when the hostname from `host_address(host)`, in lower case, is `localhost`, `127.0.0.1`, or `::1`, add `httr2::req_options(noproxy = <hostname>)`. Probe that curl matches `LOCALHOST` and `[::1]` against that value. Update the roxygen block of `lms_client()`. Leave `no_server_hint()` unchanged.
- [ ] T3: Add the `NEWS.md` entry of AC5.
- [ ] T4: Run the AC4 greps, `devtools::document()`, `devtools::test()`, and `devtools::check()`. If LM Studio runs, also call `lms_server_ready()` with `http_proxy` set to a closed port, and log the result in one work-log line.

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
- 2026-10-18: lessons harvested: M004 (socket rules differ by system; httpuv must be in DESCRIPTION, which it is) and M087 (time test blocks on an idle machine, since each case waits 0.5 s).

## Decisions

## Review
