# M008: Tests that fail on the branch they name

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — test-suite changes only, no exported behavior or documentation changes
- **Branch/PR:** `m008-test-discrimination`

## Goal

Close the seven recorded gaps where a test passes although the code path it names is broken.

## Scope

**In:** `tests/testthat/` only. Host assertions for all eight REST wrappers and for
`lms_unload_all()`'s forwarding. Body assertions read off the serialized request. The raw-body
fallback split by cause. The character-vector shape test and the two nothing-loaded message
assertions made able to fail. The verb assertion in `test-list.R`. The two inline `req_perform`
closures folded onto the shared recorder.

**Out:**
- Any change under `R/`. A plant that exposes a real defect becomes a candidate row or a `/hotfix`, never a fix on this branch.
- The abort-contract behavior gaps → they stay candidate rows. Those are the unbounded non-JSON message body and the TCP probe that does not make sure that the listener is LM Studio.
- The three source-grepping guard checkers → they stay candidate rows.
- CI and workflow cleanup → it stays candidate rows.

## Acceptance criteria

- [ ] AC1: Every wrapper named in the `api_error_callers` list in `tests/testthat/test-api-error.R`
      is called with a non-default host. The test asserts that host on the recorded request. Two
      plants each turn `devtools::test()` red. One drops `host = host` from the `lms_unload()` call
      inside `lms_unload_all()` (`R/unload.R:104`). The other drops `host` from the `lms_client()`
      call in `list_models()`.
- [ ] AC2: No test file under `tests/testthat/` reads a request body off the httr2 request object:
      `grep -rnE 'body\$data|body\[\["data"\]\]' tests/testthat/` returns no match. The
      `lms_unload()` dots test and the `lms_unload_all()` loop test read their body assertions from
      what `httr2::req_dry_run()` reports.
- [ ] AC3: Two tests cover the raw-body fallback of `api_error_message()`: one whose response
      carries `Content-Type: text/plain`, one whose response carries `Content-Type:
      application/json` with a body that is not parseable JSON. Both assert the full abort message
      with `fixed = TRUE`. Plant: `api_error_message()` returning its status fallback in place of
      the body text turns both red.
- [ ] AC4: The `lms_unload_all()` character-vector shape test goes red when `as.character(x)` in
      `R/unload.R` is replaced by `return(x)`.
- [ ] AC5: Both `expect_message()` assertions for the nothing-loaded path in
      `tests/testthat/test-unload.R` match the message including its terminal period, with
      `fixed = TRUE`. Plant: changing that message in `R/unload.R` to "No models are currently
      loaded here." turns both red.
- [ ] AC6: The `list_models()` path test in `tests/testthat/test-list.R` also asserts the HTTP
      method `GET`. Plant: adding a JSON body to the `list_models()` request, which makes httr2
      infer POST, turns it red.
- [ ] AC7: No test file outside `tests/testthat/helper-mock-http.R` names `req_perform`:
      `grep -rn 'req_perform' tests/testthat/` matches that file alone. The `lms_load()` body test
      and the `lms_chat()` openresponses test obtain their fake response through
      `local_request_recorder()`.
- [ ] AC8: The profile's verify slot is clean: `devtools::test()` reports 0 failures,
      `devtools::document()` produces no diff, and `devtools::check()` reports 0 errors and
      0 warnings.

## Coverage

- AC1 → T1, T2, T9
- AC2 → T1, T3, T9
- AC3 → T4, T9
- AC4 → T5, T9
- AC5 → T6, T9
- AC6 → T7, T9
- AC7 → T8, T9
- AC8 → T9

## Tasks

- [x] T1: Extend `request_target()` in `tests/testthat/helper-mock-http.R` to return the host header
      and the serialized body that `httr2::req_dry_run()` reports, beside the method and path it
      already returns. Keep the `httpuv` skip.
- [x] T2: Give each entry of `api_error_callers` in `tests/testthat/test-api-error.R` a host
      argument, and add one test looping over `names(api_error_callers)` that calls each wrapper
      with a non-default host and asserts that host on the recorded request. Add a test in
      `tests/testthat/test-unload.R` asserting that `lms_unload_all()` forwards its host to every
      `lms_unload()` request.
- [x] T3: Move the two body assertions in `tests/testthat/test-unload.R` off `req$body$data` and
      onto the serialized body from T1.
- [x] T4: Split the raw-body fallback coverage in `tests/testthat/test-unload.R` into a `text/plain`
      response and an unparseable `application/json` response.
- [x] T5: Change the character-vector shape test in `tests/testthat/test-unload.R` to feed a
      non-character vector, so the `as.character()` coercion is load-bearing.
- [x] T6: Anchor the two nothing-loaded `expect_message()` assertions in
      `tests/testthat/test-unload.R` on the full message text with `fixed = TRUE`.
- [x] T7: Add the `GET` assertion to the path test in `tests/testthat/test-list.R`.
- [ ] T8: Fold the inline `req_perform` closures in `tests/testthat/test-load.R` and
      `tests/testthat/test-chat.R` onto `local_request_recorder()`.
- [ ] T9: Planted-defect pass: apply each plant AC1, AC3, AC4, AC5 and AC6 name, record the result,
      revert it. Then run `devtools::test()`, `devtools::document()` and `devtools::check()` clean.

## Work log

- 2026-09-18: created by /milestone-plan.
- 2026-09-18: criteria audit ran in reduced mode (internal tier) and returned two findings, both fixed before the file was written. AC2's unprocedured "instead" clause narrowed to a two-spelling grep plus two named tests. AC7's promise narrowed to the `req_perform` token its grep enumerates.
- 2026-09-18: plan gate chose covering all eight wrappers in `api_error_callers` over covering the two unload functions alone because that list already enumerates the domain; falsified by a wrapper in the list that takes no `host` argument.
- 2026-09-18: plan gate chose reading the request through `httr2::req_dry_run()` over reading the request object's own fields because the dry run reports what goes over the wire; falsified by a CI run that skips these tests for a missing `httpuv`.
- 2026-09-18: plan gate chose folding the two inline `req_perform` closures into the shared recorder over leaving them a candidate row because D-004's own consequences name that folding; falsified by a closure whose response shape the recorder cannot produce.
- 2026-09-18: plan gate chose two raw-body tests, one per cause, over correcting the single test's content type because the parse-failure cause otherwise carries no test of its own; falsified by the two causes proving indistinguishable at the abort.
- 2026-09-18: eight criteria sits at the split tripwire and was not split, because each criterion is one small test edit inside one pull request and no part of it ships independently.
- 2026-09-18: implement gate chose a parsed list for the body `request_target()` reports, over a text string. Every request this package sends is JSON. Falsified by a wrapper that sends a body in another format.
- 2026-09-18: implement gate chose a host argument on each `api_error_callers` entry's `call`, over a second call field. One call expression per wrapper cannot drift from itself. Falsified by a wrapper the two loops must call differently.
- 2026-09-18: T1 done. `request_target()` now reports the host header and the parsed request body beside the method and path. Suite 147 pass, 0 fail, 0 skip.
- 2026-09-18: T2 done. Two host-forwarding tests added, one looping the eight wrappers and one for `lms_unload_all()`. Both plants ran early and turned red on the dropped host, reporting `localhost:1234`. Suite 150 pass, 0 fail, 0 skip.
- 2026-09-18: T3 done. The two `test-unload.R` body assertions now read the serialized body. AC2's grep still matches `test-load.R`, which T8 folds onto the recorder.
- 2026-09-18: T4 done. The raw-body fallback now has one `text/plain` test and one unparseable `application/json` test. The plant ran early. Both went red, each reporting `API Unload Failed: HTTP Status 502` in place of the body text.
- 2026-09-18: T5 done. The plain-vector shape test now feeds numbers, so the `as.character()` coercion carries the result. The plant ran early and reddened that one test alone.
- 2026-09-18: T6 done. Both nothing-loaded assertions now match the full message with `fixed = TRUE`. The plant ran early and reddened both, at `test-unload.R:147` and `test-unload.R:282`.
- 2026-09-18: T7 done. The `list_models()` path test now asserts `GET`. The plant added a JSON body to the request. The verb assertion went red at `test-list.R:17`, and the recorded-fixture test errored too, because the cassette holds no POST.

## Decisions

## Review
