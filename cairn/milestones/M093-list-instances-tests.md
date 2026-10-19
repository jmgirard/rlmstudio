<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M093: list_instances tests for a two-kind field and an empty display name

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** —   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — the help of the exported `list_instances()` can change, and the tests ship in the package   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m093-list-instances-tests   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

Tests pin two `list_instances()` cases that the code handles today with no
test, and a live reply checks the help sentence about the fields that only
`lms ps --json` gives.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** a test of a `config` field that holds a number in one instance and a
string in another. A test of a model whose `display_name` is `""`. A live
reading of `lms ps --json` and `GET /api/v1/models` with one instance loaded
with a ttl, and a correction of the help sentence at `R/list.R:157-158` if the
reading contradicts it.

**Out:** columns for the generation status, the queued requests, the ttl, or
the last-used time. They stay in the candidate row "list_instances fields and
tests", which post-merge hygiene narrows to that part. A NEWS entry: no
function changes behavior.

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

- [x] AC1: `tests/testthat/test-list-instances.R` has a test in which one
      `config` field holds a whole JSON number in one instance and a JSON
      string in another, is present and not `null` in no other instance, and
      is never an object or array. The test asserts with `expect_identical()`
      that the column is the list of the integer and the string, in row order.
- [x] AC2: `tests/testthat/test-list-instances.R` has a test in which a model
      of type `"llm"` with one loaded instance has `display_name` `""`. The
      test asserts with `expect_identical()` that the `display_name` of that
      row, found by its id, is `""`, and the call does not abort.
- [x] AC3: In one session, an instance is loaded with a ttl set, and
      `lms ps --json` and `GET /api/v1/models` are read. For each of the four
      `lms ps` keys that give the generation status, the queued requests, the
      ttl, and the last-used time, the reply is searched at any depth for a
      key of the same name, ignoring case. The help of `list_instances()`
      (`R/list.R` and `man/list_instances.Rd`) still names as absent each of
      the four whose key has no such match, and no longer names as absent
      each one whose key has one.
- [x] AC4: `Rscript -e 'devtools::document()'` produces no diff, and
      `Rscript -e 'devtools::test()'` reports no failure and no error.

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number (AC/Task counted
     top-to-bottom). Review reads to fence evidence — tracking-rules "AC fencing". -->

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T1, T2, T3, T4

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. Every item opens with its positional label —
     `Tn:` — the item's position counted top-to-bottom, the number Coverage
     cites; an insertion, removal, or reorder renumbers the labels and the
     Coverage lines together. -->

- [x] T1: Add the two-kind test beside "an object, an array, or mixed kinds
      give a list-column" (`test-list-instances.R:200`), through
      `config_frame()`. Plant `length(kinds) > 2` for `length(kinds) > 1` in
      `config_column()` (`R/list.R`) in a scratch copy and see the new test
      red while the three-kind test stays green. Also plant a coercion of the
      two kinds to character and see it red. Restore, and log both plants.
- [x] T2: Add the empty `display_name` test beside "an absent or null
      display_name or config gives NA" (`test-list-instances.R:342`), through
      `run_list_instances()` with `display_name = '""'` and a second model
      whose name is not empty. Plant `display_name <- NA_character_` for an
      empty name in `list_instances()`, then a rejection of `""` in
      `instance_list_fault()`, and see each red. Restore, and log the plants.
- [x] T3: Live reading with the token in `~/.lms-token`. Start the server on
      1234 and load an already-downloaded small model with
      `lms load <key> --ttl 600`. Download nothing. Read `lms ps --json`,
      `lms version`, and `GET /api/v1/models`. Write one work-log line with
      the LM Studio version, every key of the `lms ps` entry, which four keys
      give the four fields, and the match result of each. If a key matches,
      narrow the sentence at `R/list.R:157-158` and run `document()`.
      Unload, start on 1234, and stop the server (M083 lesson).
- [x] T4: Run the verify slot: `devtools::document()` with no diff, then
      `devtools::test()` clean.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates.
     EXEMPT from the 150-line cap (D-046): history under D-045, never edited,
     so the cap must never demand a trim here. Wrapped entries get a WARN.
     The rejected-alternative record (/milestone-plan step 4) takes this form:
     `- YYYY-MM-DD: plan gate chose <approach> over <alternative> because
     <reason>; falsified by <evidence class>.` — one per approach choice the
     gate actually weighed, none where it weighed none, and it is the record
     `/milestone-review`'s thrash trigger (b) reads. It lives here rather than
     below so an instantiated file inherits no placeholder to delete.
     A milestone of a feature series also carries the plan's
     `feature series: M<a> -> M<b>[ -> …]` line (tracking-rules "Feature series"). -->

- 2026-10-18: created by /milestone-plan.
- 2026-10-18: tier check: not run — work named at the question set.
- 2026-10-18: question set: which candidate to plan — "list_instances fields and tests", test part, with the four fields left in the row.
- 2026-10-18: question set: may implement and review start the local LM Studio server and send live requests with the token in `~/.lms-token` — yes.
- 2026-10-18: collision check: absorbs the candidate row "list_instances fields and tests" (test part). Extends M050 (done, PR #50), which shipped `list_instances()`. No D-entry covers these cases. Inbox sweep: 0 open issues, 0 open PRs.
- 2026-10-18: lessons applied: M003 (plant each defect in a scratch copy and see red), M019 (`expect_identical()` with `info` in loops), M083 (end a live probe with a start on 1234 and a stop, download nothing).
- 2026-10-18: criteria audit (full mode, fresh Opus reader) returned 4 findings. AC1 and AC2 could pass for the wrong reason: fixed by naming the exact input shape and an `expect_identical()` assert. AC3 was not decidable over prose field names, was met by deleting the sentence, and read an idle reply with no ttl: narrowed to a same-name key match, ignoring case, for the four `lms ps` keys, with the help bound both ways and a ttl load. The reader's stem search (`ttl`, `queue`, `lastused`) was declined as a recalled-spelling list. AC4: no finding.
- 2026-10-18: plan chose mocked JSON-text bodies through the existing helpers over a new recorded reply, because a live server gives no `""` display name or two-kind config field on demand; falsified by a recorded reply that holds either shape.
- 2026-10-18: no NEWS entry: no function changes behavior, and a help correction from T3 is a doc fix.
- 2026-10-18: started; branch m093-list-instances-tests cut from main at 5de6eb3.
- 2026-10-18: T1 done: test "a field of one number and one string gives a list-column" expects `list(8192L, "auto")`. Plants in a scratch copy of `R/list.R`: `length(kinds) > 2` made the new test error at the `vapply()` type step while the three-kind test stayed green; a character coercion of the number-string mix made it fail. Both restored (`cmp` clean). `devtools::test()`: 3055 blocks, 0 failed, 0 errors, 3 skipped.
- 2026-10-18: T2 done: test "an empty display_name stays an empty string" expects `""` for instance i1 and "Model Two" for i2, found by id. Plants in the scratch copy: an empty name set to `NA` in `list_instances()` made it fail; a rejection of `""` in `instance_list_fault()` made it error, and the condition was the `display_name` "is not a string" bad-response abort. Both restored (`cmp` clean). `devtools::test()`: 3056 blocks, 0 failed, 0 errors, 3 skipped.
- 2026-10-18: T3 live reading, LM Studio 0.4.26+4 (lms CLI commit dcefd5a), `google/gemma-3-1b` loaded with `--ttl 600`. `lms ps --json` entry keys: type, modelKey, format, displayName, publisher, path, sizeBytes, indexedModelIdentifier, deviceIdentifier, paramsString, architecture, quantization, variants, selectedVariant, identifier, ttlMs, lastUsedTime, vision, trainedForToolUse, maxContextLength, contextLength, status, queued, parallel, engineConfigFileEnabled. The four fields: status (generation status), queued (queued requests), ttlMs (ttl), lastUsedTime (last-used time). A sweep of all 28 distinct keys of `GET /api/v1/models` at any depth, ignoring case, found none of the four. The instance object holds id, config (context_length, parallel), and remaining_ttl_seconds (600). So the help sentence at `R/list.R:157-158` stays unchanged. The candidate row now records `remaining_ttl_seconds`. Teardown: unload all, server stopped on 1234, `lms ps --json` empty.
- 2026-10-18: T4 done: `devtools::document()` left no diff; `devtools::test()`: 3056 blocks, 0 failed, 0 errors, 3 skipped.
- 2026-10-18: claim audit: 2 claims read, 0 corrected — tests/testthat/test-list-instances.R
- 2026-10-18: status review; handed to /milestone-review.
- 2026-10-19: step-7 approval: m093-list-instances-tests approved for merge

## Decisions
<!-- owner: implement / review · append-only; milestone-local; promote
     cross-cutting ones to cairn/DECISIONS.md.
     EXEMPT from the 150-line cap (D-074) because D-045 makes it history like the work log — dated dispositions, never edited — so the cap must never demand a trim here either.
     Entries carry their rationale; the counterweight `decisions format`
     advisory watches for pasted output, not for entry length (D-075). -->

## Review
<!-- owner: review · exclusive; evidence per criterion, consistency-gate
     results, review findings + triage. EXEMPT from the 150-line cap (M55),
     as are the work log (D-046) and the decisions section (D-074); evidence
     never scrambles plan-owned content. -->

- AC1 evidence (2026-10-18): `test-list-instances.R:217` "a field of one number and one string gives a list-column" builds `{"two": 8192}` and `{"two": "auto"}` through `config_frame()`, two instances only, and asserts `expect_identical(res$two, list(8192L, "auto"))`. Fresh `test_file()` run: 1 expectation, 0 failed, no error. Discrimination: two plants in T1 work log.
- AC2 evidence (2026-10-18): `test-list-instances.R:369` "an empty display_name stays an empty string" uses an `"llm"` model `m1` with `display_name` `""` and instance `i1`, plus a control model with "Model Two", calls `run_list_instances()` directly (an abort errors the test), and asserts `expect_identical(res$display_name[res$id == "i1"], "")`. Fresh run: 2 expectations, 0 failed, no error. Discrimination: two plants in T2 work log.
- AC3 evidence (2026-10-18, fresh review session): server started on 1234, `google/gemma-3-1b` loaded with `--ttl 600`; `lms ps --json` entry holds `status`, `queued`, `ttlMs` (600000), and `lastUsedTime`. A sweep of all 28 distinct keys of `GET /api/v1/models` (1 loaded instance) at any depth, ignoring case, matched none of the four. The help still names all four as absent (`R/list.R:157-158`, `man/list_instances.Rd:52`), and `git diff main...HEAD -- R man` is empty. Teardown: unloaded, server stopped.
- AC4 evidence (2026-10-19): `devtools::document()` left no change outside the milestone file; `devtools::test()`: 3056 blocks, 0 failed, 0 errors, 3 skipped.
- Consistency gate (2026-10-19, at b9a3013): `cairn_validate` all checks passed; `document()` no diff; README.md not older than README.Rmd and neither touched; `pkgdown::check_pkgdown()` no problems; changelog: no entry, no behavior change (plan work-log line); no new top-level files; `devtools::check()` 0 errors, 0 warnings, 0 notes. `cairn_impact` skipped: no principle changed.
- spawned: diff-bug, blame-history, prior-review, ripple
- diff-bug #1: help says the model list does not carry the ttl, while the live reply carries `remaining_ttl_seconds` — fix now (help names the field and says `list_instances()` does not read it; the four stay named as absent, so AC3 holds), fixed 1b29714.
- diff-bug #2: T3 names a start on 1234 in the teardown, and the records list only unload and stop — reject, false: the probe started on 1234 and never moved the port, so that start was the M083 step.
- diff-bug #3: the candidate row names `remaining_ttl_seconds` and leaves open whether it meets the row's promotion condition — fix now (row says the four are absent under those names and puts a column for the field in the row), fixed 1b29714.
- diff-bug #4: help says `display_name` is `NA` when the list gives none, and does not say that `""` stays `""` — fix now (help adds it; the null case is tested by "an absent or null display_name or config gives NA"), fixed 1b29714.
- diff-bug #5: the reply keys rest on log text, and 25 `lms ps` keys sit beside a 28-key REST count — reject, false: AC3 evidence re-ran the reading fresh at review, and each count names its source.
- diff-bug #6: the two-kind test overlaps the three-kind test — reject, planned change: only the new test catches the `> 2` plant (T1).
- blame-history #1: the row says the REST list does not carry the four, then names `remaining_ttl_seconds` — fix now (same row rewording as diff-bug #3), fixed 1b29714.
- blame-history #2: the two-kind test adds no new branch in `config_column()` — reject, planned change: the plan asked to isolate the two-kind case.
- prior-review: no finding (archived reviews of M050, M052, M056, M057 read; PR comment probe empty).
- ripple #1: `R/list.R:157-158` needs the `remaining_ttl_seconds` qualifier — fix now (same help edit as diff-bug #1), fixed 1b29714.
- ripple #2: `man/list_instances.Rd:51-52` goes stale with ripple #1 — fix now (regenerated by `document()`), fixed 1b29714.
- ripple #3: `cairn/references/lmstudio-api-surface.md:153-154` lacks the `remaining_ttl_seconds` observation — fix now (corrected in place, marked M093), fixed 1b29714.
- AC3 evidence after the fixes (2026-10-19): `R/list.R` and `man/list_instances.Rd` still name the generation status, the queued requests, the ttl, and the last-used time as absent from the model list; the added sentence names `remaining_ttl_seconds`, which matches none of the four `lms ps` keys. AC3 holds.
- Re-verify after fixes (2026-10-19, at 1b29714): `devtools::test()` 3056 blocks, 0 failed, 0 errors, 3 skipped; `document()` no diff; `devtools::check()` 0 errors, 0 warnings, 0 notes; `cairn_validate` all checks passed.
