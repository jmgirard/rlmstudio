<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M019: A failed input no longer ends a chat batch

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP2, GP3, GP6   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — changes what an exported function returns and raises   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m019-batch-survives-errors   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

`lms_chat_batch()` stores an API failure or an unreadable reply in the failed input's slot and goes on, and a lost server still aborts but hands back the replies received so far.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** In every setting of `lms_chat_batch()`, an `rlmstudio_api_error` or `rlmstudio_bad_response` from one input is stored and the batch goes on. M018 did this for `rlmstudio_bad_response` with a `schema` only. A list result holds the condition. A vector or a data frame without a `schema` holds `NA_character_`. One warning names every failed position and ignores `quiet`. An `rlmstudio_no_server` from `lms_chat()` still aborts, and its condition gains a `results` field. D-011 records the choices and extends D-010. The help pages and `NEWS.md` change to match. This absorbs the candidate row "An `rlmstudio_api_error` or `rlmstudio_no_server` from one input still aborts `lms_chat_batch()`".

**Out:** An argument that restores the abort on the first failure. The plan gate declined it, and no row holds it. A reply that the token limit cut off but that still parses stays its own candidate row (M018 review). A data-frame `error` column was declined at the plan gate. The replies lost to a user interrupt (Ctrl-C) are not in scope, and no row holds them. Errors of any other class still abort.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets.
     Every item opens with its positional label — `ACn:` — the item's
     position counted top-to-bottom, the number Coverage cites; an
     insertion, removal, or reorder renumbers the labels and the Coverage
     lines together.
     Driving RR set → its Binding criteria appear VERBATIM here (binding-
     criteria check), each ingested as a numbered criterion carrying its tag
     — `- [ ] ACn (BCm): <verbatim>` — with its own Coverage line, since
     coverage-complete counts AC checkboxes positionally (M107); departures:
     a "Deviations from RR<NN>" table ends this section. -->

- [x] AC1: An `rlmstudio_api_error` or an `rlmstudio_bad_response` that `lms_chat()` raises for one input no longer aborts `lms_chat_batch()`. The batch sends a request for every later input and returns. Tests run a three-input batch with `api_type = "openai"`, where both classes can arise, once per class in six settings. These are `format = "list"`, `"vector"`, and `"data.frame"`, each with and without a `schema`. The second response fails in each run, and one more run per format fails the third. Two more settings test `rlmstudio_api_error` alone. The first is `simplify = FALSE` with `format = "list"`, because that setting never reads the reply. The second is the default `api_type` with `format = "list"`. One more setting, `logprobs = TRUE` with `format = "data.frame"`, tests both classes. Each test asserts three requests sent.
- [ ] AC2: The failed input keeps its position in the result. In a returned list, and in the `output` list-column that a `schema` produces, the element holds the condition with its backtrace removed. With `format = "vector"`, `simplify = TRUE`, and no `schema` or `logprobs`, the result is a character vector as long as `inputs`. It holds `NA_character_` at the failed position. With `format = "data.frame"` and no `schema`, the `output` column holds `NA_character_` in that row. With `logprobs = TRUE` the `logprobs` column holds `NULL` there. The AC1 tests assert the value at each failed and each successful position.
- [x] AC3: A batch with one or more failed inputs gives exactly one warning about failed inputs. This holds for any mix of the two classes. It names the count and every failed position, and it shows with `quiet = TRUE`. Where the result holds `NA_character_` in place of the condition, the warning names `format = "list"` as the way to keep the conditions. Each AC1 test asserts that warning, and the vector and data-frame tests without a `schema` assert the `format = "list"` text. One test fails position 1 with `rlmstudio_api_error` and position 3 with `rlmstudio_bad_response`. Under `quiet = TRUE`, it asserts one warning that names both positions.
- [x] AC4: An `rlmstudio_no_server` that `lms_chat()` raises for input k still aborts `lms_chat_batch()` with that class and message. No request goes out after it. The condition carries a new `results` field, a list as long as `inputs`. Its elements 1 to k - 1 hold the values that `format = "list"` returns for those inputs. Its elements from k on are `NULL`. The tests mock the server probe with a call counter. The batch's own probe is call 1 and passes. One test fails the probe for input 2 (k = 2) and one fails it for input 1 (k = 1). Each asserts the class, the request count, and the field.
- [x] AC5: An error of any other class from `lms_chat()` still aborts `lms_chat_batch()` unchanged. Two tests stub `lms_chat()` with a call counter that raises for the second of three inputs. One raises a plain R error, and one raises an rlang error with a class that is not an rlmstudio class. Each asserts with `expect_identical()` that the caught condition is the one raised, and that the stub ran twice.
- [x] AC6: No help source, vignette, `README.Rmd`, or development-section `NEWS.md` entry says that `rlmstudio_api_error` or `rlmstudio_bad_response` from one input aborts `lms_chat_batch()`. The reviewer reads every line that `grep -rn -iE "abort|stop" R vignettes README.Rmd NEWS.md` returns and that mentions a batch. The reviewer also reads the `lms_chat_batch()` details and the "API failure" and "Malformed response" sections of `R/conditions.R`. `devtools::document()` leaves no diff. With `RLMSTUDIO_API_TOKEN` set, `devtools::check()` returns 0 errors, 0 warnings, and 0 notes.

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number (AC/Task counted
     top-to-bottom). Review reads to fence evidence — tracking-rules "AC fencing". -->

- AC1 → T1, T2
- AC2 → T1, T2, T8, T11
- AC3 → T1, T3
- AC4 → T4
- AC5 → T5
- AC6 → T6, T7, T9, T10

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. Every item opens with its positional label —
     `Tn:` — the item's position counted top-to-bottom, the number Coverage
     cites; an insertion, removal, or reorder renumbers the labels and the
     Coverage lines together. -->

- [x] T1: Write the AC1 to AC3 tests first, in a new batch test file, with `local_request_sequence()` from `tests/testthat/helper-mock-http.R`. Build a 400 response for `rlmstudio_api_error` and an unparseable schema reply for `rlmstudio_bad_response`. Watch them fail on the current code.
- [x] T2: In `lms_chat_batch()` (`R/chat.R:609`), catch both classes in every setting, not only when `has_parsed` is true. Drop the backtrace as now. Build the vector and the no-schema data frame with `NA_character_` in a failed slot, and `NULL` logprobs there (`R/chat.R:682`, `R/chat.R:738`).
- [x] T3: Rewrite the warning (`R/chat.R:649`) to cover both classes. Keep the positions joined with `cli::ansi_collapse(trunc = Inf)`. Add the `format = "list"` line where the result holds `NA_character_`. Keep one warning per batch. Where a failure already warned, the vector format's own list warnings must not add a second one about failed inputs.
- [x] T4: Write the AC4 tests. Then catch `rlmstudio_no_server` around the per-input call, set `results`, and signal the same condition again. Mock `is_server_running` with a counter, because `lms_chat_batch()` probes once before the first input (LESSONS M003).
- [x] T5: Write the AC5 tests with a counting stub for `lms_chat()`, not `fail()` (LESSONS M015). Confirm that the two classes other than rlmstudio pass through the handlers.
- [x] T6: Update the `lms_chat_batch()` roxygen `@return` and `@details` (`R/chat.R:540`). In `R/conditions.R`, update the "API failure" and "Malformed response" sections, and add the `results` field to "Server not running". Rewrite `NEWS.md` lines 7 and 8 and add one entry. Run `devtools::document()`.
- [x] T7: Run the AC6 grep and read each hit. Run `devtools::test()`, then `devtools::check()` with the token set.
- [x] T8: Review O1. With `format = "data.frame"` and `logprobs = TRUE`, build the `logprobs` column even when every input fails (`R/chat.R:723`). Test it first: a batch in which every input fails, asserting the column and its `NULL` slots.
- [x] T9: Review O2. Narrow the "Server not running" paragraph in `R/conditions.R` and the matching `NEWS.md` entry to a server that the check before an input finds gone. A drop during a request raises another error and carries no `results`. Run `devtools::document()`.
- [x] T10: Review O7, O8, and O9 in `tests/testthat/test-chat-batch.R`. Add a test that named `inputs` keep their names in a list, a vector, and the `results` field. Assert the "Returning list" text in the vector-with-`schema` warning. Give `expect_length(res$warnings, 1L)` its `info`. Pass `parsed` in the `fail_response()` call on the default `api_type`. Run `devtools::test()` and `devtools::check()` with the token.
- [x] T11: Claim audit after the return. A reply with `"content": null` beside a failed input made a vector short and a data frame abort. Store `NA` for a NULL reply in the text paths, test it first, and correct the three claims the audit flagged.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates.
     EXEMPT from the 150-line cap (D-046): history under D-045, never edited,
     so the cap must never demand a trim here. Wrapped entries get a WARN.
     The rejected-alternative record (/milestone-plan step 4) takes this form:
     `- YYYY-MM-DD: plan gate chose <approach> over <alternative> because
     <reason>; falsified by <evidence class>.` — one per approach choice the
     gate actually weighed, none where it weighed none, and it is the record
     `/milestone-review`'s thrash trigger (b) reads. It lives here rather than
     below so an instantiated file inherits no placeholder to delete. -->

- 2026-09-22: created by /milestone-plan.
- 2026-09-22: criteria audit (full mode, fresh Opus reader) returned 14 findings. All were fixed before the gate: `api_type = "openai"` for the reply class, formats named for `simplify = FALSE` and `logprobs`, last-position and k = 1 runs, a second error class, "one warning about failed inputs", the D-010 gap, and a named docs sweep.
- 2026-09-22: plan gate chose to abort on a lost server with the replies attached over storing it and going on, because a lost server fails every later input and GP3 says a missing server is an error. Falsified by a user who needs the batch to resume after the server restarts mid-run.
- 2026-09-22: plan gate chose `NA_character_` in a failed vector or data-frame slot over a data-frame `error` column or a switch to a list, because the result type then does not depend on what failed (GP2). Falsified by users who need the condition from a data-frame batch and cannot rerun with `format = "list"`.
- 2026-09-22: plan gate chose no `on_error` argument over adding one, because an argument is hard to remove and the warning already marks the failures. Falsified by a user who needs a batch to stop at the first failure.
- 2026-09-22: implement started on branch m019-batch-survives-errors. Question gate skipped, because the plan left no API, naming, or dependency choice open.
- 2026-09-22: T1 to T3 done in one checkpoint. `tests/testthat/test-chat-batch.R` failed on the old code with the abort, then passed. The shared chat bodies moved to `tests/testthat/helper-chat-bodies.R`. Two M018 tests that asserted the old abort were removed. The `data.frame` plus `simplify = FALSE` abort now runs before the failed-input warning, so that setting no longer warns and then aborts. Every vector fallback to a list now folds into the one failed-input warning, not only the `schema` one. Full suite: 0 failed.
- 2026-09-22: T4 done. The three AC4 tests failed on the missing `results` field, then passed. The loop is now a `for` loop that fills a preset list, so the handler can attach the results so far. A named `inputs` still gives a named result, checked against the pre-change code. Full suite: 0 failed.
- 2026-09-22: T5 done. The AC5 test catches with `tryCatch()`, because `expect_error()` adds a backtrace and never returns the raised object. A planted `error =` catch-all in the batch loop turned it red on both the identity and the call count, and it is green without it.
- 2026-09-22: T6 done. The batch `@return` and `@details`, the three sections in `R/conditions.R`, and two `NEWS.md` entries were rewritten, and one entry was added. The "Server not running" paragraph about `results` reaches every page that inherits that section, 12 pages in all. A test now pins the documented claim that the probe before the first input adds no `results` field.
- 2026-09-22: T7 done. The AC6 grep returned 13 lines that mention a batch, and none says an API failure or an unreadable reply aborts it. The development `NEWS.md` entry on one failure path still says the batch's failures "change in the same way", which holds for the class and `status` of the stored condition. `devtools::document()` left no diff. `devtools::check()` with the token: 0 errors, 0 warnings, 0 notes.
- claim audit: 22 claims read, 4 corrected — R/chat.R, NEWS.md, tests/testthat/test-chat-batch.R
- 2026-09-22: claim audit corrections: a data frame with `schema` and `logprobs = TRUE` also holds `NA`, the `results` field also holds stored failures, and the AC5 comment names `tryCatch()`. The same fresh reader re-read all four as true. Left as is: a data frame with `simplify = FALSE` runs every input and then aborts on the argument, with no failed-input warning.
- 2026-09-22: review returned M019 to in-progress (defect return 1). AC2 fails: with `format = "data.frame"` and `logprobs = TRUE`, a batch in which every input fails has no `logprobs` column. The gate added T8 to T10 for that fix, the lost-server help text, and three test gaps.
- 2026-09-22: review pushed the branch to origin by mistake with the send-back commit, before any merge approval. No PR exists.
- 2026-09-22: implement resumed after the review return. Question gate skipped, because T8 to T10 leave no choice open.
- 2026-09-22: T8 done. The new all-failed test lacked the `logprobs` column on the old code, then passed. The data-frame branch now keys the column on the `logprobs` argument, not on the results. A batch whose replies all came back without logprobs now also gets the column, as `@return` says. Full suite: 2139 expectations, 0 failed.
- 2026-09-22: T9 done. "Server not running" and the `NEWS.md` entry now limit `results` to a server that the check before an input finds gone. A run with the check mocked to pass and `host` on a closed port raised `httr2_failure` with no `results`, and a new test pins that. `devtools::document()` regenerated 13 pages. Batch tests: 301 expectations, 0 failed.
- 2026-09-22: T10 done. New test: named `inputs` keep their names in a list, a vector, and `results`. The vector-with-`schema` runs assert the "Returning list" reason, the loop's warning count carries `info`, and both `fail_response()` calls pass `parsed`. A planted drop of the reason line and a planted drop of the names each turned a test red, and both were reverted. Batch tests: 312 expectations, 0 failed. `devtools::document()` left no diff. `devtools::check()` with the token: 0 errors, 0 warnings, 0 notes.

## Decisions
<!-- owner: implement / review · append-only; milestone-local; promote
     cross-cutting ones to cairn/DECISIONS.md.
     EXEMPT from the 150-line cap (D-074) because D-045 makes it history like the work log — dated dispositions, never edited — so the cap must never demand a trim here either.
     Entries carry their rationale; the counterweight `decisions format`
     advisory watches for pasted output, not for entry length (D-075). -->

## Review
<!-- owner: review · exclusive -->

Fresh evidence, 2026-09-22, on the branch head with `main` already merged in (no sync needed).

- AC1: The test "a failed input in any format does not end the batch" in `test-chat-batch.R` runs both classes in the three formats, with and without a `schema`, on `api_type = "openai"`. It fails position 2, then position 3, and each run asserts 3 requests. Three more tests each assert 3 requests. One covers `simplify = FALSE` with `format = "list"` for an API error. One covers the default `api_type` with `format = "list"` for an API error and asserts the `/v1/responses` route. One covers `logprobs = TRUE` with `format = "data.frame"` for both classes. The file ran 287 expectations with 0 failed and 0 skipped.
- AC2: The same tests assert every position. A list slot and a `schema` `output` slot hold the condition with a `NULL` `trace`, and an API error slot keeps `status` 400. A vector and a data frame without a `schema` equal `c("reply 1", NA, "reply 3")` with the failure at its position. The logprobs test asserts `NULL` at the failed row and a data frame at the others.
- AC3: Each AC1 run asserts exactly one warning with the count and the position. The runs that hold `NA` assert the `format = "list"` text, and the others assert its absence. The mixed test fails position 1 with an API error and position 3 with an unreadable reply under `quiet = TRUE` and the `rlmstudio.quiet` option. It asserts one warning, "2 inputs failed, at positions 1 and 3".
- AC4: The probe mock counts calls. For k = 2 it asserts `rlmstudio_no_server`, 3 probes, 1 request, and `results` equal to `list("reply 1", NULL, NULL)`. For k = 1 it asserts 2 probes, 0 requests, and three `NULL` elements. The code signals the same condition object again with `stop(cnd)`, so the message does not change. Two more tests pin that the first probe adds no `results` field and that `results` keeps a stored failure.
- AC5: One test stubs `lms_chat()` with a call counter that raises on call 2, once with `simpleError()` and once with an rlang error of class `some_other_error`. It catches with `tryCatch()` and asserts with `expect_identical()` that the caught condition is the one raised and that the stub ran twice. The work log records the planted catch-all that turned it red.
- AC6: The grep returned 13 lines that mention a batch. I read each one, 6 in `R/` and 7 in `NEWS.md`. None says that an API failure or an unreadable reply from one input aborts the batch. `NEWS.md` line 39 says the batch's failures "change in the same way", which describes the condition class and `status` and claims no abort. I read the batch details and the two named sections of `R/conditions.R` in the diff. `devtools::document()` left no diff. `devtools::check()` with the token gave 0 errors, 0 warnings, and 0 notes.
- Consistency gate: `cairn_validate.py` passed with exit 0. No DESIGN principle changed, so the impact report was skipped. `README.Rmd` did not change. No `_pkgdown.yml` exists. `NEWS.md` has the entries, and no new top-level file needs a `.Rbuildignore` line.

Independent review: three fresh reviewers, full fan-out (user-facing tier). Findings, ranked, with the proposed disposition. The gate decides each one.

- O1: With `format = "data.frame"` and `logprobs = TRUE`, a batch in which every input fails has no `logprobs` column. The code builds the column only when some result is an `lms_chat_result` (`R/chat.R:723`). I confirmed it with a mock run, which gave the columns `input` and `output` only. This breaks AC2, which says the column holds `NULL` at a failed row. Proposed: fix now, which returns the milestone to in-progress.
- O2: The "Server not running" text in `R/conditions.R:31` says that a server lost during the batch aborts it with `rlmstudio_no_server` and a `results` field. That holds only when the check before an input catches it. A server that drops while a request is in flight raises `httr2_failure`, which passes through with no `results`. Proposed: fix now by narrowing the text to the check.
- O3: A bad token (401) or a model that is not loaded (404) fails every input, so the batch sends every request and then warns. Proposed: follow-up candidate row.
- O4: The OpenResponses and native routes do not check the reply shape. `{"output": []}` aborts the batch with "subscript out of bounds", and a reply with no `text` gives a short vector. This predates M019. Proposed: follow-up candidate row.
- O5: A data frame with `simplify = FALSE` sends every request before it aborts on the argument. This predates M019. Proposed: follow-up candidate row.
- O6: The `results` paragraph shows on the 12 help pages that inherit "Server not running". It names `lms_chat_batch()`, so it reads correctly there. Proposed: reject, noted in T6.
- O7: No test pins that named `inputs` keep their names in the new loop. Proposed: fix now with one test.
- O8: Test gaps. The vector-with-`schema` run does not assert that the "Returning list" reason is in the one warning. `expect_length(res$warnings, 1L)` in the loop has no `info`. No run uses `quiet = FALSE` with a failure. Proposed: fix now for the first two, and reject the third because the progress bar has no failure path.
- O9: `fail_response("rlmstudio_api_error")` at `test-chat-batch.R:162` omits `parsed` and works only because `switch()` does not evaluate the other branch. Proposed: fix now.
- S1: The warning's first sentence no longer names a condition class. T3 planned this, and the second line names both classes. Proposed: reject as planned.
- Prior-review lens: no prior-review regression. The archive held the only review record, and the PR-comment probe returned nothing.
- Gate, 2026-09-22: the user chose "Send back and fix". O1, O2, O7, O8 (first two parts), and O9 are fix now, as tasks T8 to T10. O3, O4, and O5 are follow-up candidate rows. O6, S1, and the third part of O8 are rejected for the reasons above.
