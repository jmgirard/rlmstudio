<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M091: Test dry runs skip a set proxy, and two helper comments match each system

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** —   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** internal — test helpers and test comments, which no package user relies on   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m091-dry-run-test-gaps   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

The test dry runs of `helper-mock-http.R` reach the echo server when a proxy
is set, and the comments of two test helpers state what happens on macOS and
on Linux.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** the three gaps of the candidate row "dry-run test comment gaps".
Correct the comment above the never-replies block of
`tests/testthat/test-mock-http-helper.R` to the two results of row E3 of
`cairn/references/curl-echo-fault.md`. Correct the `free_port()` comment of
`tests/testthat/helper-ports.R`. Make `request_dry_run()` in
`tests/testthat/helper-mock-http.R` send each dry run with
`httr2::req_options(noproxy = "*")`, and add a test that sets the proxy
variables.

**Out:**
- Whether the package's own requests to LM Studio skip a set proxy → the
  candidate row "proxy and local requests", added at this plan. This
  milestone changes test helpers only.
- Removing the dry-run retry once curl binds its echo server to 127.0.0.1 →
  the candidate row "dry-run retry exit".
- Any change to `R/` or to a user-facing doc → none is needed, so no NEWS
  entry.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [x] AC1: The comment above the `test_that()` block "request_target() reads
      a request when the program on the first dry-run port never replies" in
      `tests/testthat/test-mock-http-helper.R` states that the first try ends
      with curl's timeout error on macOS and with httpuv's "Failed to create
      server" on Linux, the two results that row E3 of
      `cairn/references/curl-echo-fault.md` records.
- [x] AC2: The comment above `free_port()` in `tests/testthat/helper-ports.R`
      does not say that nothing listens on the returned port. It states that
      on macOS the returned port can be one that another program holds on
      127.0.0.1 alone.
- [x] AC3: With `http_proxy` and `all_proxy` set to `http://127.0.0.1:<port>`
      for a port that `free_port()` returned, and `no_proxy` and `NO_PROXY`
      set to empty strings, `request_target()` reads the method, path, and
      body of a request in 1 dry-run try.
- [x] AC4: `devtools::test()` on macOS, run with no proxy variables set,
      reports 0 failures and 0 warnings.

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number (AC/Task counted
     top-to-bottom). Review reads to fence evidence — tracking-rules "AC fencing". -->

- AC1 → T1
- AC2 → T1
- AC3 → T2
- AC4 → T3

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. Every item opens with its positional label —
     `Tn:` — the item's position counted top-to-bottom, the number Coverage
     cites; an insertion, removal, or reorder renumbers the labels and the
     Coverage lines together. -->

- [x] T1: Correct the two comments. First probe on macOS: hold a port on
      127.0.0.1 alone with `httpuv::startServer()`, then confirm that
      `serverSocket()` on that port succeeds, so `bind_free_port()` can
      return it. Write the `free_port()` comment from that probe and the
      never-replies comment from row E3 (derived-claims rule).
- [x] T2: Test first. In `tests/testthat/test-mock-http-helper.R`, add a
      test that sets the AC3 variables with `withr::local_envvar()`, counts
      tries with `local_dry_run_ports()`, and asserts method, path, body, and
      `tries$n` of 1. See it fail on the current helper with the helper's "no
      request" stop. Then add `httr2::req_options(req, noproxy = "*")` to
      `request_dry_run()` and extend its comment with the proxy case. Plant
      check: remove the option and see the new test go red. No `curl::` call
      (LESSONS M004).
- [x] T3: Run `devtools::document()` (no diff expected), `devtools::test()`,
      and `devtools::check()`.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-10-18: created by /milestone-plan.
- 2026-10-18: tier check: not run — work named at the question set.
- 2026-10-18: question set: which candidate to plan — the dry-run test gaps; fix the proxy gap too, or the comments only — the comments and the proxy.
- 2026-10-18: collision sweep: absorbs the candidate row "dry-run test comment gaps"; distinct from the parked row "dry-run retry exit" (removes the retry, not touched here); no D-entry, archive, or Known issues overlap on proxies; GitHub inbox has 0 open issues and 0 open PRs.
- 2026-10-18: probe on macOS: with `http_proxy=http://127.0.0.1:9`, a dry run failed with `curl_error_couldnt_connect` to port 9, and with `req_options(noproxy = "*")` or `proxy = ""` it read the request.
- 2026-10-18: lessons harvested: M004 (no `curl::` call in tests, since DESCRIPTION does not list curl), PR #85 hotfix (Linux libcurl differs, CI covers Ubuntu).
- 2026-10-18: plan gate chose `httr2::req_options(noproxy = "*")` on the request over setting `no_proxy` with `withr` inside the helper, because the option binds to the curl handle and does not depend on which variable spellings libcurl reads; falsified by an httr2 or curl release whose dry run ignores the handle's `noproxy` option.
- 2026-10-18: criteria audit (reduced mode, fresh Opus reader): AC1 and AC2 no finding; AC3 bound an instrument ("as a test asserts"), so the criterion narrowed to the helper's behavior and the test moved to T2; AC4 borderline, narrowed to a run with no proxy variables set.
- 2026-10-18: added the candidate row "proxy and local requests" for the package's own requests, outside this test-only scope.
- 2026-10-18: implement started on branch `m091-dry-run-test-gaps`, cut from `22eeadb`.
- 2026-10-18: T1 done: probe on macOS (R 4.6.1) held port 31234 on 127.0.0.1 with httpuv, and `serverSocket(31234)` then returned a connection; the `free_port()` comment and the never-replies comment now state the macOS and Linux results (row E3); `devtools::test()` 0 failed, 0 errors, 0 warnings, 3 skipped.
- 2026-10-18: T2: the first draft of the proxy test took the proxy port and the echo port from two bare `free_port()` calls, which return the same port, so the echo server acted as the proxy and the test failed on an absolute-URL path; the echo port now leaves the proxy port out of its scan.
- 2026-10-18: T2 done: on the old helper the proxy test failed with the helper's stop "The dry run received no request in 5 tries", last error `Could not connect to server` to the proxy port; with `httr2::req_options(req, noproxy = "*")` in `request_dry_run()` it passes in 1 try; `devtools::test()` 0 failed, 0 errors, 0 warnings, 3 skipped.
- 2026-10-18: T3 done: `devtools::document()` left no diff; `devtools::check()` 0 errors, 0 warnings, 0 notes (proxy variables unset).
- 2026-10-18: claim audit: not owed — internal tier.
- 2026-10-18: implement complete; status set to review.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

## Review
<!-- owner: review · exclusive -->

Branch synced: `origin/main` is `22eeadb`, the branch's base, so no merge was needed (2026-10-18).

- AC1 evidence: `test-mock-http-helper.R:137-142` says that on macOS "the first try ends with curl's timeout error" and that on Linux "the first try ends with httpuv's \"Failed to create server\"", matching row E3 of `cairn/references/curl-echo-fault.md` (macOS `curl_error_operation_timedout`, Linux "Failed to create server").
- AC2 evidence: `grep -n "nothing listens" tests/testthat/helper-ports.R` finds no line; `helper-ports.R:34-37` says that on macOS the bind "also succeeds over a port that another program holds on 127.0.0.1 alone, so the returned port can be one that such a program listens on".
- AC3 evidence: a direct run outside testthat, with `http_proxy` and `all_proxy` set to `http://127.0.0.1:29096` (a `free_port()` port), `no_proxy` and `NO_PROXY` empty, and the echo port 29333, gave method POST, path `/v1/models/load`, body `{"model":"m"}`, in 1 try. In the full suite, "request_target() reads a request when a proxy is set" ran 4 expectations, 0 failed.
- AC4 evidence: `devtools::test()` on macOS with no proxy variable in the environment (`env | grep -i proxy` empty, and the six variables unset): 0 failed, 0 errors, 0 warnings, 3 skipped, 24695 expectations passed.
- Gate: `cairn_validate.py` all checks passed; `devtools::document()` left no diff; `pkgdown::check_pkgdown()` no problems; `devtools::check()` 0 errors, 0 warnings, 0 notes; README.Rmd and `R/` untouched; no NEWS entry owed (test files only); no principle changed, so no `cairn_impact` run.
