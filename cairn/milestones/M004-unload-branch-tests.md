# M004: Response and empty-list branch tests for the two unload functions

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4, GP6
- **Resolves:** —
- **Surface tier:** internal. The deliverable is the package's own test suite, which no caller of the installed package runs.
- **Branch/PR:** `m004-unload-branch-tests` / https://github.com/jmgirard/rlmstudio/pull/5

## Goal

Cover the untested response and empty-list branches of `lms_unload()` and
`lms_unload_all()` with tests that go red on a broken branch.

## Scope

**In:** New tests in `tests/testthat/test-unload.R` for the success path, the
three failure-message sources, and the dots merge of `lms_unload()`. Also for
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

- [x] AC1: On an HTTP 200 unload response, `lms_unload("m")` sends exactly one
      POST to `api/v1/models/unload` and returns `"m"` invisibly. The suite
      asserts this. When the success branch returns `NULL`, the suite fails.
- [x] AC2: If the unload response is not HTTP 200, `lms_unload()` aborts with a
      message built from the response. The function reads that message from
      three sources. The first is the `message` field inside a JSON `error`
      object. The second is a JSON `error` object with no `message` field. The
      third is the raw body text. Three response shapes reach the raw body
      text. They are a JSON body with no `error` field, a JSON body whose
      `error` is a string, and a body that is not JSON. If the chosen source is
      an empty string, the message names the HTTP status number instead. The
      suite asserts the message for the first two sources, for all three shapes
      that reach the raw body text, and for the empty string. When the message
      chain is cut back to the raw response string, the suite fails.
- [x] AC3: A named argument passed through `...` to `lms_unload()` reaches the
      request body next to `instance_id`. The suite asserts this. When the
      merge of `...` into the body is dropped, the suite fails.
- [x] AC4: If `list_models()` reports nothing loaded, `lms_unload_all()` prints
      "No models are currently loaded.", returns `NULL` invisibly, and sends no
      unload request. The suite asserts all three facts for a `list_models()`
      result with no rows. When both nothing-loaded guards are deleted, the
      suite fails.
- [x] AC5: If `list_models()` reports two loaded instances, `lms_unload_all()`
      sends one unload POST for each instance id in the reported order. It
      forwards its `...` into each request body. It returns both ids invisibly.
      The suite asserts all three facts. When only the first instance is
      unloaded, the suite fails.
- [x] AC6: `lms_unload_all()` reads instance ids from the four
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
- [x] T2: Add the failure-message tests for `lms_unload()`. Cover the first two
      sources, the three response shapes that reach the raw body text, and the
      empty-string case. Each mock returns a non-200 response with the body that
      selects its source (R/unload.R:55).
- [x] T3: Add the nothing-loaded test for `lms_unload_all()`. Mock
      `list_models` to return an empty data frame. Assert the message, the
      invisible `NULL`, and that `httr2::req_perform` was never called
      (R/unload.R:113).
- [x] T4: Add the unload-loop test for `lms_unload_all()`. Mock `list_models`
      to report two loaded instances. Assert the two captured request bodies,
      their order, the forwarded dots, and the returned ids (R/unload.R:148).
- [x] T5: Add the four instance-id shape tests and the `NA` and empty filter
      test for `lms_unload_all()` (R/unload.R:120).
- [x] T6: Run the planted-defect pass. For each criterion, break the named
      behavior in `R/unload.R` itself, because `devtools::test()` loads only the
      real file. Make sure that the matching test goes red. Then restore the file
      with `git checkout -- R/unload.R`. Record one work-log line per criterion
      naming the plant and the failure seen.
- [x] T7: Run `Rscript -e 'devtools::document()'`, `Rscript -e
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
- 2026-09-18: superseding an earlier line above. The empty-message case is reached through `{"error": {"message": ""}}`, not through a JSON body whose `error` field is an empty string. A string `error` field aborts at `err_json$error$message` and falls to the raw body text.
- 2026-09-18: two T2 tests failed and showed that AC2 described a source the code does not reach. A JSON `error` field holding a string aborts on `$` and falls back to the raw body text.
- 2026-09-18: re-audit: AC2 (reduced) — nothing.
- 2026-09-18: substantive amendment accepted at a mini gate. AC2 now states three message sources and the three response shapes that reach the raw body text. No criterion was added. T2 was reworded to match.
- 2026-09-18: probing found a third latent defect. A JSON `error` field holding an empty array crashes `lms_unload()` with "argument is of length zero". Filed as a candidate row.
- 2026-09-18: T2 done. Five tests cover the two object sources, the three shapes that reach the raw body text, and the empty-string fallback to the HTTP status number. Suite 81 pass, 0 fail.
- 2026-09-18: T3 done. One test asserts the message, the invisible `NULL`, and zero recorded requests on the nothing-loaded path. Suite 85 pass, 0 fail.
- 2026-09-18: T4 done. One test asserts two requests, their instance ids in order, the forwarded `ttl`, both unload paths, and the returned ids. Suite 91 pass, 0 fail.
- 2026-09-18: T5 done. Six tests cover the four `loaded_instances` shapes, the all-dropped filter result, and a partial filter. The `identifier` and `id` shapes carry a decoy first column, so a first-column fallback cannot pass them. Suite 100 pass, 0 fail.
- 2026-09-18: T6 plant for AC1. `return(invisible(model))` became `return(invisible(NULL))`. One failure, at the success-path test, 33 pass.
- 2026-09-18: T6 plant for AC2. The `tryCatch` message chain became `err_msg <- httr2::resp_body_string(resp)`. Three failures, at the nested-message, error-object, and HTTP-status tests, 31 pass.
- 2026-09-18: T6 plant for AC3. `utils::modifyList(list(instance_id = model), list(...))` became `list(instance_id = model)`. Two failures, at the dots test and the unload-loop test, 31 pass.
- 2026-09-18: T6 plant for AC4 as planned. The first nothing-loaded guard was deleted. Zero failures, 34 pass. The second guard produces the same message, the same invisible `NULL`, and no request for that input.
- 2026-09-18: T6 plant for AC4 as amended. Both nothing-loaded guards were deleted. Three failures, at the nothing-loaded test and the all-dropped filter test, 31 pass.
- 2026-09-18: T6 plant for AC5. The unload loop ran over `loaded_keys[1]`. Four failures, all in the unload-loop test, 30 pass.
- 2026-09-18: T6 plant for AC6. The `identifier` and `id` branches were deleted, leaving the first-column fallback. Two failures, at the identifier-shape and id-shape tests, 32 pass.
- 2026-09-18: re-audit: AC4 (reduced) — two findings. A clause reasoning that the second guard catches every input the first one catches was an unbounded promise and was disproportionate for the internal tier. Both sentences were dropped before the gate.
- 2026-09-18: re-audit: AC4 (reduced) — nothing.
- 2026-09-18: substantive amendment accepted at a mini gate. AC4 now names the no-rows input and asks the suite to catch the deletion of both nothing-loaded guards. No criterion was added.
- 2026-09-18: the Scope In paragraph was changed from four failure-message sources to three, to match the gated AC2 amendment. The change is that amendment applied to the sentence restating its count, not a new scope decision.
- 2026-09-18: T6 done. Every criterion has a plant that turns its own tests red, AC4 after its amendment. `R/unload.R` was restored after each plant and the tree is clean.
- 2026-09-18: the AC4 audit produced a counterexample. A zero-row result whose `loaded_instances` column still holds an entry reaches the first guard and not the second. No real server response takes that shape, so no candidate row was filed and no guard was called redundant.
- 2026-09-18: T7 done. `devtools::document()` produced no diff. `devtools::test()` gave 100 pass, 0 fail, 0 warn, 0 skip. `devtools::check()` gave 0 errors, 0 warnings, 0 notes, so no NOTE reason is owed.
- 2026-09-18: claim audit: not owed — internal tier.
- 2026-09-18: status set to review at the end of implement.
- 2026-09-18: review ran every acceptance criterion with fresh evidence. Suite 100 pass, 0 fail. `devtools::check()` 0 errors, 0 warnings, 0 notes. `cairn_validate` clean with no advisory. Every plant a criterion names was re-run and went red.
- 2026-09-18: three fresh-context reviewers ran. The prior-review and blame-history lenses found nothing blocking. The diff-bug lens reported twelve findings, and every claim naming a plant was re-run before triage. No finding met the return floor.
- 2026-09-18: gate directed two fixes. The mock recorder now applies the request's error policy, and D-004 records the HTTP-testing style choice. Five findings became four candidate rows, three were rejected, and two were noted.
- 2026-09-18: step-7 approval: m004-unload-branch-tests approved for merge.
- 2026-09-18: CI on PR #5 failed two tests that the local suite passed. `httr2::req_dry_run()` needs `httpuv`, which is present on this machine and absent on the runners.
- 2026-09-18: gate chose adding `httpuv` to Suggests over reading the path off `req$url`, recorded as D-005. When `httpuv` is absent, `request_target()` now skips its caller. Suite 100 pass, check 0/0/0.

## Decisions

## Review

Evidence run 2026-09-18 on branch `m004-unload-branch-tests`, level with
`origin/main`. Full suite: 100 pass, 0 fail, 0 warn, 0 skip. Each plant below
was applied to `R/unload.R`, run under `devtools::test(filter = "unload")`, and
reverted with `git checkout --`. The tree was clean afterward.

- AC1 met. The success-path test asserts one recorded request, method POST,
  path `/api/v1/models/unload`, and the invisible `"test-model"`. Plant:
  `return(invisible(model))` became `return(invisible(NULL))`. Result 1 fail at
  test-unload.R:26, 33 pass.
- AC2 met. Five tests assert the message for the nested `message` field and for
  an `error` object with no `message` field. They also assert it for the three
  shapes that reach the raw body text. Those shapes are a body with no `error`
  field, a string `error` field, and a body that is not JSON. A fifth test
  asserts the empty string falling back to "HTTP Status 503". Plant: the
  `tryCatch` chain became `err_msg <- httr2::resp_body_string(resp)`. Result 3
  fail at test-unload.R:51, :62, and :108, 31 pass.
- AC3 met. The dots test asserts `ttl = 300` in the request body next to
  `instance_id`. Plant: the body became `list(instance_id = model)`, dropping
  the `utils::modifyList()` merge. Result 2 fail, the first at test-unload.R:42,
  31 pass.
- AC4 met. The nothing-loaded test asserts the message, the invisible `NULL`,
  and zero recorded requests for a `list_models()` result with no rows. Plant:
  both nothing-loaded guards were deleted. Result 3 fail at test-unload.R:122,
  :226, and :231, 31 pass.
- AC5 met. The loop test asserts two recorded requests, the instance ids
  `inst-1` then `inst-2` in that order, `ttl = 60` in both bodies, both unload
  paths, and the two returned ids. Plant: the loop ran over `loaded_keys[1]`.
  Result 4 fail at test-unload.R:155, :158, :162, and :165, 30 pass.
- AC6 met. Six tests assert the ids read from the four shapes. The `identifier`
  and `id` frames each carry a decoy first column, so a first-column fallback
  cannot pass them. The other tests cover the first-column fallback, a plain
  character vector, an all-dropped `NA` and empty filter returning invisible
  `NULL`, and a partial filter. Plant: the `identifier` and `id` branches were
  deleted, leaving the fallback. Result 2 fail at test-unload.R:191 and :198,
  32 pass.

Consistency gate, all clean. `cairn_validate.py` passed every check with no
advisory fired. No principle text changed, so no impact report was owed.
`devtools::document()` produced no diff. `devtools::check()` gave 0 errors, 0
warnings, 0 notes. `pkgdown::check_pkgdown()` found no problems. The diff adds
no top-level file, so no `.Rbuildignore` entry is owed. README.md is in sync
with README.Rmd and neither was touched. No `NEWS.md` entry is owed, because
nothing a caller can observe changed.

### Independent review

Three fresh-context reviewers ran against distinct evidence bases. The
prior-review lens found no regression against past findings. The blame-history
lens found nothing that reverses an earlier milestone and one future-cleanup
item. The diff-bug lens reported twelve findings. Each claim below that names a
plant was re-run against `R/unload.R` before it was triaged.

1. The mock bypasses httr2's error policy, so the `req_error(is_error = FALSE)`
   line at R/unload.R:48 has no test. Reproduced. Deleting that line leaves the
   suite at 34 pass, 0 fail. Disposition: fix now. A prototype that reads
   `req$policies$error_is_error` in the recorder keeps the real suite green and
   turns six failure tests red on that plant.
2. No test asserts that `host` reaches the wire, and `lms_unload_all()` does not
   assert that it forwards `host`. Reproduced. Dropping `host = host` at
   R/unload.R:149 leaves the suite at 34 pass, 0 fail. Disposition: follow-up
   candidate row. No criterion of M004 promises host coverage, so this is a
   pre-existing gap of the M001 class.
3. Body assertions read `req$body$data`, an httr2 internal field, rather than
   the serialized request. Disposition: follow-up candidate row, with finding 2.
4. AC4 was narrowed to a plant the suite catches, leaving the first
   nothing-loaded guard untested on its own. Disposition: reject. The narrowing
   went through the gated amendment protocol during implement, and the work log
   records the counterexample and the reason it was not filed.
5. The non-JSON body test sends a `Content-Type: application/json` header, so it
   models a parse failure rather than a non-JSON response. Disposition:
   follow-up candidate row.
6. GP6 is named in the header but nothing in the diff asserts quiet behavior.
   Disposition: noted. The header slot is plan-owned and this milestone asserts
   no quiet behavior.
7. The suite now holds a third way to fake `req_perform()`, beside the inline
   closures and the `httptest2` cassettes. DESIGN names recorded fixtures as the
   everyday contract. The blame lens raised the same point. Disposition: fix
   now. Record the choice as a D-entry, because it binds the next milestone that
   writes an HTTP test.
8. The character-vector shape test cannot fail on its own branch. Reproduced.
   Replacing `as.character(x)` with `return(x)` leaves the suite at 34 pass, 0
   fail. Disposition: follow-up candidate row, with finding 5.
9. The helper's `body = ""` affordance is unused and its only path aborts inside
   httr2. Disposition: noted. That path is the defect already filed as a
   candidate row.
10. Two shared fixtures sit mid-file in `test-unload.R` rather than in the
    helper. Disposition: reject. A style placement point on a working file.
11. The two message matchers are unanchored regexes with an unescaped dot, while
    every error matcher in the file uses `fixed = TRUE`. Disposition: follow-up
    candidate row, with finding 5.
12. `ids_read_from()` passes `.package` where no other test does. Disposition:
    reject. A style nitpick with no behavior behind it.

No finding meets the return floor. Every plant an acceptance criterion names
was re-run and went red. No criterion failed inside the domain of its own named
procedure. The package's behavior is unchanged by this branch.

### Gate outcome

The maintainer directed the two fix-now items and candidate rows for the rest.
Finding 1 is fixed. `local_request_recorder()` now reads
`req$policies$error_is_error` and raises through `httr2::resp_check_status()`.
The real suite stays green, and deleting the `req_error()` line from
`R/unload.R` now gives 6 fail, 28 pass. Finding 7 is fixed as D-004, which
sanctions two HTTP-testing styles and names the third as a candidate row.
Findings 2, 3, 5, 8, and 11 became four candidate rows. Findings 4, 10, and 12
were rejected, and findings 6 and 9 were noted with no action.

