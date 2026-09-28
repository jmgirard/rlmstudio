# M048: The embedding help page describes the cut of a text longer than the context

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2
- **Resolves:** —
- **Surface tier:** user-facing — the help page of an exported function
- **Branch/PR:** m048-embed-context-cut

## Goal

The `lms_embed()` help page says that LM Studio embeds only the start of a text longer than the loaded context.
It also says how to avoid the cut.

## Scope

**In:** a details paragraph on the `lms_embed()` help page and a live test that pins what it says. Also a NEWS
bullet and a dated record of the probe in `cairn/references/lmstudio-api-surface.md`.
The probe ran on LM Studio 0.4.25+1 on 2026-09-28 with text-embedding-nomic-embed-text-v1.5. At a 2048-token
context, a 5000-word text gave the same vector as its first 2500 words. At `context_length` 512, it gave the
same vector as its first 520 words. Its first 510 words gave a different vector. The reply carried status 200,
no error, and `usage` of 0 tokens. A short text also reports 0 tokens. `POST /v1/tokenize` and
`/api/v0/tokenize` answered "Unexpected endpoint or method".

**Out:** a warning from an estimated token count, and splitting a long text and combining the vectors. The
package cannot count tokens, so both go to one candidate row that names the evidence to promote it.

## Acceptance criteria

- [x] AC1: The `lms_embed()` help page says that the server embeds only the first tokens of each text, up to the
      context length of the loaded model instance, as observed on LM Studio 0.4.25+1. It says that the server
      then returns a vector for the cut text with no error or warning. It says that the reply's `usage` field
      reported 0 tokens on that version, so the count does not show the cut. It names two ways to avoid the cut.
      The first is to split a long text before the call. The second is to load the model with a larger
      `context_length` through `lms_load()`, up to the `max_context_length` column of
      `list_models(detailed = TRUE)`.
- [x] AC2: The cut that the `lms_embed()` help page describes holds on a live LM Studio server with
      text-embedding-nomic-embed-text-v1.5 loaded. Let N be the `context_length` of that loaded instance in
      `list_models(detailed = TRUE)`. One `lms_embed()` call sends three texts in one request. The first two texts
      share their first N words and differ only after them, and they get the same vector. The third text differs
      from the first only in its first word, and it gets a different vector. The call gives no warning. The same
      three texts with `simplify = FALSE` return a body whose `usage` reports 0 prompt tokens.
- [x] AC3: `devtools::test()` and `devtools::check()` pass with 0 errors and 0 warnings, and
      `devtools::document()` leaves no diff.

## Coverage

- AC1 → T1, T3, T4
- AC2 → T2
- AC3 → T5

## Tasks

- [x] T1: Record the probe facts from Scope in `cairn/references/lmstudio-api-surface.md` as a dated
      observation with the LM Studio version. Put it under the features of endpoints the package calls.
- [x] T2: Add a live test after the existing live test in `tests/testthat/test-embed.R` (near line 1110). It skips
      as that test does and never loads a model. It reads N from the `loaded_instances` config of
      `list_models(detailed = TRUE)`. It builds the three texts from ordinary words, each at least one token.
      Assert the AC2 cases, with `expect_no_warning()` around the call. Run it live and record that it ran and did
      not skip, which is the review evidence for AC2. Plant a defect, such as a shared start of 10 words, and see
      it fail.
- [x] T3: Add the AC1 paragraph to the `@details` of `R/embed.R`, written against the probe record from T1. Run
      `devtools::document()`.
- [x] T4: Add a NEWS.md bullet under the development version that says what the help page now documents.
- [x] T5: Run `devtools::test()`. Then run `devtools::check()` with `RLMSTUDIO_API_TOKEN` set and the server
      started (LESSONS, M009).

## Work log

- 2026-09-28: created by /milestone-plan.
- 2026-09-28: criteria audit (full) by a fresh [O] reader returned six findings. All six were fixed before the gate. The claims name LM Studio 0.4.25+1. N comes from the loaded instance. The third text differs in its first word. One request carries all texts. The test checks for no warning and for `usage`. AC2 states the server behavior, not the test.
- 2026-09-28: plan gate chose documenting the cut over a warning from an estimated token count. The server has no tokenize endpoint and reports 0 tokens, so an estimate fires wrongly in both directions. Falsified by an LM Studio reply or endpoint that gives a token count.
- 2026-09-28: plan gate chose documenting the cut over splitting a long text and averaging the vectors. That changes what a vector means and needs a token count that the package cannot get. Falsified by a user who needs one vector for a whole long document.
- 2026-09-28: implement started on branch m048-embed-context-cut. The question gate was skipped, because the plan left no choice open.
- 2026-09-28: T1 done. The probe facts are an "Embedding context cut" entry in `cairn/references/lmstudio-api-surface.md`, dated and with the LM Studio version.
- 2026-09-28: T2 done. The live test ran against LM Studio 0.4.25+1 with nomic loaded at 2048 tokens. It did not skip and passed 4 expectations. With a planted shared start of 10 words, the same-vector check failed with a difference of 0.090. The session loaded nomic and started the server for the run.
- 2026-09-28: `devtools::test()` passed 464 tests with 0 failures and 0 skips. The Full Integration test unloaded `google/gemma-3-1b`, as the candidate row says. The session reloads it at the end.
- 2026-09-28: T3 done. The `@details` of `R/embed.R` has the AC1 paragraph, and `devtools::document()` rewrote `man/lms_embed.Rd`.
- 2026-09-28: T4 done. NEWS.md has a bullet under the development version, after the batching bullet.
- 2026-09-28: T5 done. `devtools::check()` with the token and the server running gave 0 errors, 0 warnings, and 0 notes. `devtools::document()` left no diff.
- 2026-09-28: claim audit: 22 claims read, 1 corrected — NEWS.md, R/embed.R, man/lms_embed.Rd, tests/testthat/test-embed.R
- 2026-09-28: the corrected claim is the NEWS bullet, which said "loaded model" where the help page says "loaded model instance". The reader did not reach the server. The T2 live run already read `context_length` from the embedding instance, which settles its one open doubt.
- 2026-09-28: all tasks done, status set to review.
- 2026-09-28: review started. AC1 and AC2 have evidence. The AC3 check and the three reviewers are still running (checkpoint).
- 2026-09-28: gate fixes for review findings O1, O3, O5, O6, O7, S1, and S2 are on the branch. Tests and check are rerunning before the merge chip.
- step-7 approval: m048-embed-context-cut approved for merge

## Decisions

## Review

- Sync: 2026-09-28, `origin/main` at 7cf66ab, the branch base. No merge needed.
- AC1: `tools::Rd2txt("man/lms_embed.Rd")` renders the paragraph. It states each clause of AC1: the cut at the
  context length of the loaded model instance on LM Studio 0.4.25+1, and a vector with no error or warning. It also
  states `usage` of 0 tokens and the two ways to avoid the cut. Live, `list_models(type = "embedding", detailed = TRUE)` has a
  `max_context_length` column (2048 for nomic), and `lms_load()` has a `context_length` argument. Pass.
- AC2: live run on LM Studio 0.4.25+1, nomic loaded as one instance at `context_length` 2048. The test
  "live: the server embeds only the first context-length tokens" ran, did not skip, and passed 4 of 4
  expectations. They cover no warning, the same vector for texts one and two, and another vector for text three.
  They also cover `usage` 0 prompt tokens with `simplify = FALSE`. The test failed on a planted defect at T2.
  Pass.
- AC3: `devtools::test()` passed 464 tests, 12876 expectations, 0 failures, 0 skips. `devtools::check()` with the
  token and the server running gave 0 errors, 0 warnings, and 0 notes. `devtools::document()` left no diff. Pass.
- Gate: `cairn_validate.py` exit 0, all checks passed. `pkgdown::check_pkgdown()` found no problems. NEWS.md has
  a bullet with no milestone number. README.Rmd and `.Rbuildignore` are not touched. DESIGN.md is not touched, so
  `cairn_impact` does not apply. No driving RR.
- Reviewers: [O] diff-bug 9 findings, [S] blame-history 3, [S] prior-review 0 (no regression of an archived
  finding, and no GitHub review threads). Dispositions below are proposed, pending the gate.
- O1: the second remedy fails for a user whose model is already loaded. `lms_load()` without `force` returns
  early with "already loaded" (R/load.R:79-88, read at review). Proposed fix now: the help and NEWS say to
  unload first with `lms_unload()`.
- O2: the probe fits a cut fixed near 512 tokens as well as a cut at `context_length`. Proposed reject. A live
  probe at review ran with nomic at 2048. The vector equals the 5000-word vector from 2100 words on. At 2040
  words it differs by 0.031. Record the two points in the references page.
- O3: the live test pins only an upper bound on the cut, so a cut at 64 tokens passes it. Proposed fix now: a
  fourth text that differs from text one at word N %/% 2 gets another vector.
- O4: the `tryCatch()` around `list_models()` turns a 401 or a bad reply into the skip "is not loaded". The
  neighboring live test has the same pattern. Proposed follow-up: one candidate row for both live tests.
- O5 and S3: N is the largest context of all loaded instances, where AC2 says "that loaded instance". A missing
  `context_length` gives `max(NULL)`. Proposed fix now: skip unless exactly one instance with a context length.
- O6: the NEWS bullet says "reports" with no version, and it uses "You can". Neighbors state what the package
  does. Proposed fix now.
- O7: the help names the ceiling, not where the current context length shows. Proposed fix now: one clause
  naming the `loaded_instances` column of `list_models(detailed = TRUE)`.
- O8: GPU rounding can break the 1e-6 tolerance. Proposed reject: the neighbor test uses it, and the planted
  defect gave 0.090.
- O9: the milestone file had uncommitted changes. Reject: stale, committed at c5d8c4d and 0ab29f5.
- S1: the NEWS bullet sits below the batching bullet. M046 and M047 put the newest bullet first. Proposed fix now.
- S2: the new live test lacks the neighbor's comment that it never loads a model. Proposed fix now.
- Gate triage 2026-09-28: the maintainer chose to fix, then re-ask. Fixed now: O1, O3, O5 and S3, O6, O7, S1,
  S2. Rejected as proposed: O2, O8, O9. Follow-up: O4, as a candidate row. The probe points of O2 went to the
  references page.
- Fix evidence: the live test passed 5 of 5 expectations with nomic at 2048 and did not skip. A copy with the
  word moved past the cut (`mid <- n + 50L`) failed at the new check alone, with a difference of 0.
- Evidence after the fixes: the rendered help keeps every AC1 clause and adds the unload step. `devtools::test()`
  passed 464 tests, 12877 expectations, 0 failures, 0 skips. `devtools::document()` left no diff. The first
  `devtools::check()` failed once at test-arg-guards.R:799, where `req_dry_run()` got "Empty reply from server".
  That file is not in the diff. The rerun at 53bff7b gave 0 errors, 0 warnings, 0 notes. `cairn_validate` failed
  weight caps at 60 ROADMAP lines after the O4 row. Two sibling guard rows were merged, and it passes.
