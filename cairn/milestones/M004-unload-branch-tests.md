# M004: Response and empty-list branch tests for the two unload functions

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4, GP6
- **Resolves:** —
- **Surface tier:** internal. The deliverable is the package's own test suite, which no caller of the installed package runs.
- **Branch/PR:** `m004-unload-branch-tests`

## Goal

Cover the untested response and empty-list branches of `lms_unload()` and
`lms_unload_all()` with tests that go red on a broken branch.

## Scope

**In:** New tests in `tests/testthat/test-unload.R` for the success path, the
four failure-message sources, and the dots merge of `lms_unload()`. Also for
the nothing-loaded path, the unload loop, and the four instance-id shapes of
`lms_unload_all()`. The tests drive the HTTP layer by mocking
`httr2::req_perform` and return synthetic `httr2::response()` objects, in the
style of `tests/testthat/test-load.R`. A planted-defect pass proves that each
new test can fail.

**Out:** Any change under `R/`. If a new test exposes a defect, the fix goes
to `/hotfix` with its failing test first. A shared condition class for the six
API-failure aborts goes to a candidate row. The same untested response
branches in `lms_load()`, `lms_download()`, `lms_download_status()`, and the
three chat functions go to a candidate row. New recorded `httptest2` fixtures
are not needed. The tests build their responses in R. No `NEWS.md` entry is
owed. No user-visible behavior changes.

## Acceptance criteria

- [ ] AC1: On an HTTP 200 unload response, `lms_unload("m")` sends exactly one
      POST to `api/v1/models/unload` and returns `"m"` invisibly. The suite
      asserts this. When the success branch returns `NULL`, the suite fails.
- [ ] AC2: If the unload response is not HTTP 200, `lms_unload()` aborts with a
      message built from the response. The function reads that message from
      four sources. The first is the `error$message` field of a JSON body. The
      second is the `error` field of a JSON body. When the JSON carries no
      `error` field, the third source is the raw body text. When the body does
      not parse as JSON, the fourth source is the raw body text. If the result
      is empty, the message names the HTTP status number instead. The suite
      asserts the message for each of the four sources and for the empty
      result. When the message chain is cut back to the raw response string,
      the suite fails.
- [ ] AC3: A named argument passed through `...` to `lms_unload()` reaches the
      request body next to `instance_id`. The suite asserts this. When the
      merge of `...` into the body is dropped, the suite fails.
- [ ] AC4: If `list_models()` reports nothing loaded, `lms_unload_all()` prints
      "No models are currently loaded.", returns `NULL` invisibly, and sends no
      unload request. The suite asserts all three facts. When that early return
      is deleted, the suite fails.
- [ ] AC5: If `list_models()` reports two loaded instances, `lms_unload_all()`
      sends one unload POST for each instance id in the reported order. It
      forwards its `...` into each request body. It returns both ids invisibly.
      The suite asserts all three facts. When only the first instance is
      unloaded, the suite fails.
- [ ] AC6: `lms_unload_all()` reads instance ids from the four
      `loaded_instances` shapes the function distinguishes. Two are a data
      frame with an `identifier` column and a data frame with an `id` column.
      The other two are a data frame with neither column and a plain character
      vector. It drops ids that are `NA` or empty. If that leaves no ids, it
      returns `NULL` invisibly. The suite asserts the ids read from each shape
      and the filtering result. When the extraction always returns the first
      column, the suite fails.

## Coverage

- AC1 → T1, T6
- AC2 → T2, T6
- AC3 → T1, T6
- AC4 → T3, T6
- AC5 → T4, T6
- AC6 → T5, T6

## Tasks

- [x] T1: Add the success-path and dots tests for `lms_unload()`. Mock
      `is_server_running` to `TRUE` and `httr2::req_perform` to capture the
      request and return a 200 response. Assert the returned value, the request
      count, the URL path, and both body fields (R/unload.R:34).
- [ ] T2: Add the four failure-message tests and the empty-body test for
      `lms_unload()`. Each mock returns a non-200 response with the body that
      selects its source (R/unload.R:55).
- [ ] T3: Add the nothing-loaded test for `lms_unload_all()`. Mock
      `list_models` to return an empty data frame. Assert the message, the
      invisible `NULL`, and that `httr2::req_perform` was never called
      (R/unload.R:113).
- [ ] T4: Add the unload-loop test for `lms_unload_all()`. Mock `list_models`
      to report two loaded instances. Assert the two captured request bodies,
      their order, the forwarded dots, and the returned ids (R/unload.R:148).
- [ ] T5: Add the four instance-id shape tests and the `NA` and empty filter
      test for `lms_unload_all()` (R/unload.R:120).
- [ ] T6: Run the planted-defect pass. For each criterion, break the named
      behavior in `R/unload.R` itself, because `devtools::test()` loads only the
      real file. Make sure that the matching test goes red. Then restore the file
      with `git checkout -- R/unload.R`. Record one work-log line per criterion
      naming the plant and the failure seen.
- [ ] T7: Run `Rscript -e 'devtools::document()'`, `Rscript -e
      'devtools::test()'`, and `Rscript -e 'devtools::check()'`. Record the
      counts. State a reason for each NOTE.

## Work log

- 2026-09-18: created by /milestone-plan.
- 2026-09-18: criteria audit ran in reduced mode and returned three findings. Two named one defect in AC2, which miscounted the error-message sources and treated the empty-body override as a source. AC2 was rewritten, re-checked by the same fresh reader, and cleared. The third named AC7 as a promise about the check tool rather than about the deliverable. The gate accepted it, AC7 was removed, and the check run became T7.
- 2026-09-18: a healthy server returns no failure status, and a committed fixture owes a generator script. So the plan gate chose synthetic `httr2::req_perform` mocks over new `httptest2` recordings. Falsified by evidence that a hand-built `httr2::response()` diverges from what `httr2` builds from a real socket.
- 2026-09-18: a shared condition class spans six abort sites in four files. So the plan gate chose message matchers over adding one. Falsified by evidence that the abort text changes often enough to make the matchers brittle.
- 2026-09-18: plan gate chose testing all four instance-id branches over only the shapes a real server sends. Falsified by evidence that a behavior-preserving rewrite of the extraction turns the tests red.
- 2026-09-18: implement started on branch `m004-unload-branch-tests`, cut from the pushed default branch.
- 2026-09-18: a run against a mocked 500 with an empty body aborted from httr2, not from the intended HTTP-status fallback. Both body reads abort on an empty body.
- 2026-09-18: question gate kept M004 to tests and filed that defect as a candidate row. AC2 reaches the empty-message case through a JSON body whose `error` field is an empty string.
- 2026-09-18: question gate chose `httr2::req_dry_run(quiet = TRUE)` for the method and path assertions, over the unexported `httr2:::req_method_get()` and over leaving the verb unasserted.
- 2026-09-18: question gate chose a shared `tests/testthat/helper-mock-http.R` for the request-capturing mock, over a file-local helper and over an inline copy per test.
- 2026-09-18: minor amendment to T6. The planted-defect pass edits `R/unload.R` in place and restores it with git, because `devtools::test()` loads only the real file.
- 2026-09-18: T1 done. New `tests/testthat/helper-mock-http.R` records requests and answers them with a synthetic response. Two tests cover the success path and the dots merge. Suite 75 pass, 0 fail.

## Decisions

## Review
