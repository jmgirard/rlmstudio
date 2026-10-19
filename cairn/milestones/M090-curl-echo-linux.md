<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M090: The curl echo fault is checked on Linux and reported to curl

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** —   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** internal — test helpers, a reference page, and an upstream report, which no package user relies on   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m090-curl-echo-linux   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

A Linux run settles what the dry-run retry of `helper-mock-http.R` covers
there, a test covers the retry after a curl error on every system, and the
curl maintainers get a report of the `curl::curl_echo()` fault.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** both follow-ups of the candidate row "curl echo fault follow-ups".
Run the held-port blocks of `tests/testthat/test-mock-http-helper.R` on macOS
and in the local `rocker/r-ver:4.6` image, and record what each dry-run try
ended with on a new page, `cairn/references/curl-echo-fault.md`. Add a test
whose first try ends with a real curl error. Correct the Linux and Ubuntu
claims in the two test files to what the container run shows. Write a report
and a reproducer for `jeroen/curl`, and file the report from the operator's
account.

**Out:**
- Removing the retry of `request_dry_run()` once a curl release binds the
  echo server to 127.0.0.1 → the candidate row "dry-run retry exit", added
  at this plan.
- A fix PR to `jeroen/curl` → not asked for. The report states the fault and
  its cause, and the maintainers choose the fix.
- Any change to `R/` or to a user-facing doc → none is needed, so no NEWS
  entry.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [ ] AC1: `cairn/references/curl-echo-fault.md` exists with its line in
      `cairn/references/INDEX.md`. For each `test_that()` block of
      `tests/testthat/test-mock-http-helper.R` that calls
      `local_dry_run_ports(`, which `grep -n` over the merged file lists, the
      page records what each dry-run try ended with (a request read, an empty
      result, or a condition with its classes and message), or that the block
      skipped before any try, with its skip message. It also records the
      message of the curl error that a dry run of a URL with a space in its
      path gives. It records this for one run on macOS and one run in the
      `rocker/r-ver:4.6` container, each with its date and its curl and
      libcurl versions.
- [ ] AC2: `tests/testthat/test-mock-http-helper.R` holds a test whose first
      dry-run try ends with a condition of class `curl_error` that curl itself
      raised, not one the test builds. The test asserts that
      `request_target()` then reads the method and body of the request and
      that 2 tries ran. It holds no skip that applies on macOS or in the
      `rocker/r-ver:4.6` container with httpuv installed.
- [ ] AC3: Each comment sentence of `tests/testthat/test-mock-http-helper.R`
      and `tests/testthat/helper-mock-http.R` that holds a line listed by
      `grep -n -i -E 'linux|ubuntu'` states only a result, class, or message
      that the AC1 page records for the container run.
- [ ] AC4: The AC1 page holds a report for the curl maintainers and a
      reproducer script. The page records one run of the reproducer on macOS,
      with the curl and libcurl versions of that run, in which
      `curl::curl_echo()` returns a result with no method while another
      program listens on 127.0.0.1 alone at the port it was given. The page
      also cites the lines of `R/echo.R` on curl's default branch, at a named
      commit, that bind 0.0.0.0 and send to 127.0.0.1.
- [ ] AC5: The report is filed as an issue on `jeroen/curl`, and the AC1 page
      records its URL.
- [ ] AC6: `devtools::test()` on macOS reports 0 failures and 0 warnings.

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number. -->

- AC1 → T1, T2, T3
- AC2 → T4
- AC3 → T5
- AC4 → T6
- AC5 → T7
- AC6 → T8

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. -->

- [x] T1: Write a trace script in the scratchpad, not committed. It runs each
      block that `grep -n 'local_dry_run_ports(' tests/testthat/test-mock-http-helper.R`
      lists, plus the URL-with-space block, and logs each dry-run try: a
      request read, an empty result, or the condition's classes and message,
      or the block's skip message. Wrap `httr2::req_dry_run()` with a
      logging mock or `trace()`, so the helper itself is unchanged.
- [x] T2: Run the trace script on macOS. Record the results, the date, and
      `packageVersion("curl")` and `curl::curl_version()$version` on a new
      page, `cairn/references/curl-echo-fault.md`, from the synthesis-note
      template, and add its line to `cairn/references/INDEX.md`.
- [x] T3: Run the trace script and `test-mock-http-helper.R` in
      `rocker/r-ver:4.6`. Install `libcurl4-openssl-dev` with apt and the test
      packages from CRAN inside the container. Pass the package source on
      stdin with `tar`, as LESSONS (PR #85 hotfix) says, because Colima mounts
      only `$HOME`. Record the results on the page as in T2.
- [x] T4: Add the curl-error test to `test-mock-http-helper.R`. On try 1, the
      dry run gets a real curl error. For example, a mocked
      `curl::curl_echo()` fetches a port that no program holds, and curl
      cannot connect there on any system. Test first: in a scratch
      copy, drop `curl_error` from the retry condition of `request_dry_run()`,
      and see the test go red with the curl error itself. Then restore the
      copy. Run the test on macOS and in the container. Re-run T1's script
      on the merged file if the test calls `local_dry_run_ports(`.
- [x] T5: Run `grep -n -i -E 'linux|ubuntu'` over both test files. Rewrite
      each comment sentence that holds a listed line so it states only what
      the page records for the container run. This includes the skip text of
      the time-limit block and the "Out of memory" sentence above the
      URL-with-space block.
- [x] T6: Write a reproducer script that holds 127.0.0.1 alone at a port with
      `httpuv::startServer()` and calls `curl::curl_echo()` at that port. Run
      it on macOS, and record the result and the versions on the page. Read
      `R/echo.R` on curl's default branch with
      `gh api repos/jeroen/curl/commits/HEAD` and its contents at that commit,
      and cite the bind and target lines. Write the report text on the page
      in the register of the curl issue tracker: the fault, the reproducer,
      the macOS and Linux results, and the cause.
- [x] T7: First search `jeroen/curl` issues for the fault again. If none
      covers it, file the report with
      `gh issue create --repo jeroen/curl` from the operator's account,
      as the question set granted. Record the URL on the page. If an issue
      now covers it, record that issue's URL instead and file nothing.
- [ ] T8: Run `devtools::test()` on macOS. It reports 0 failures and 0
      warnings.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-10-18: created by /milestone-plan.
- 2026-10-18: tier check: milestone — new tests, a Linux run, and an upstream report with a design choice about how to force a curl error.
- 2026-10-18: absorbed the candidate row "curl echo fault follow-ups" in full. No collision in ROADMAP, archive, or DECISIONS beyond M066 (done, the workaround this milestone checks) and D-004 (mocked transport, which the T4 mock follows). Inbox sweep: 0 open issues, 0 open PRs.
- 2026-10-18: not split. The report cites the Linux result, so the two halves are not independently worth shipping, and together they fit one sitting.
- 2026-10-18: upstream read: curl 8.1.0 on CRAN, and `R/echo.R` on curl's default branch still binds 0.0.0.0 and sends to 127.0.0.1. No `jeroen/curl` issue covers the fault (issue 388 is about the httpuv server and not this bind).
- 2026-10-18: plan gate chose a mock that makes try 1 end with a real curl error over a Linux socket setup that gives one, because on Linux the echo server either binds 0.0.0.0 alone or fails to bind, so no socket state there gives a curl error on one try only; falsified by a Linux socket state that makes one dry-run try end with a curl error and the next succeed.
- 2026-10-18: plan gate chose to cite curl's default-branch `R/echo.R` over installing curl 8.1.0 on this Mac to run the reproducer, because a local install is outside the question set; falsified by an `R/echo.R` on the default branch that differs from the 8.0.0 installed here in the bind or target lines.
- 2026-10-18: criteria audit (reduced mode, fresh Opus reader) returned 5 findings, all taken toward the narrower promise. AC1 now records a block that skips before any try and each condition's message, plus the URL-with-space error. AC2 dropped its reporter-output clause (an instrument) for a no-skip property of the test. AC3 counts whole comment sentences that match `linux|ubuntu`, not the lines alone. AC5 says "filed", not "open". AC6 names 0 failures and 0 warnings.
- 2026-10-18: question set: who files the curl report — the agent files it from the operator's account with `gh issue create` once the reproducer confirms the fault.
- 2026-10-18: question set: run the tests in the local `rocker/r-ver:4.6` image, with apt and CRAN installs inside the container — granted.
- 2026-10-18: added the parked candidate row "dry-run retry exit" for the retry's removal once curl fixes the bind (search-first: no overlap).
- 2026-10-18: status in-progress on branch m090-curl-echo-linux, cut from main at dde3de2.
- 2026-10-18: T1 done: the trace script (scratchpad `trace-dry-run.R`, not committed) swaps `httr2::req_dry_run()` with `assignInNamespace()` and runs each block with `test_file(desc = )`. Without `NOT_CRAN=true`, the two `skip_on_cran()` blocks skip, so every run sets it.
- 2026-10-18: T2 done: macOS results recorded on `cairn/references/curl-echo-fault.md` (E1 to E6), page line added to INDEX.md.
- 2026-10-18: T3 done: in the container, every held-port try ends with "Failed to create server", and the time-limit block skips; the whole file gave 36 passed, 1 skipped, 0 failed. `docker run` pulled `rocker/r-ver:4.6` again, because this Docker context did not find the copy that `docker images` had listed. The question set granted the image and the installs inside it, and not the pull.
- 2026-10-18: T4 done: the new test mocks `curl::curl_echo()` so that call 1 runs `curl::curl_fetch_memory()` against a `free_port()` on 127.0.0.1 and call 2 runs the real echo. Planted in a scratch copy (the `curl_error` clause of the retry condition replaced by `TRUE`), it went red with `curl_error_couldnt_connect` from `curl_fetch_memory()`. It passed on macOS and in the container (file: 40 passed, 1 skipped, 0 failed). It does not call `local_dry_run_ports(`, so the AC1 domain stays 5 blocks and the trace did not need a re-run.
- 2026-10-18: T5 done: the grep lists 3 sentences. The Ubuntu 24.04 "Out of memory" sentence (E5) and the time-limit skip sentence (E6) already match the container record and stay. The new T4 comment now says that each held-port test on Linux retries on "Failed to create server" or skips (E1 to E4, E6).
- 2026-10-18: T6 done: the reproducer ran on macOS (curl 8.0.0, libcurl 8.14.1): `find_port()` returned the held port, and `curl_echo()` returned a list with `url` alone. In the container it got `NULL` from `find_port()` and "Failed to create server". The page cites `R/echo.R` lines 62, 84, 94 and `src/findport.c` lines 52, 63 at curl commit d4f60d6.
- 2026-10-18: T7 done: two searches of `jeroen/curl` issues found no report of the fault. Filed https://github.com/jeroen/curl/issues/459 from the operator's account, as the question set granted, and recorded the URL on the page.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

## Review
<!-- owner: review · exclusive. -->
