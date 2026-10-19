<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M094: list_instances remaining ttl column

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP1   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — a new column in the result of the exported `list_instances()`   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m094-list-instances-ttl-column   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

`list_instances()` returns the `remaining_ttl_seconds` of each loaded instance
as a new column.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** a double column `remaining_ttl_seconds`, the fifth column, read from
the instance field of that name in `GET /api/v1/models`. A type rule for the
field in `instance_list_fault()`, under the field-type rule for
model-management replies. The column in the zero-row frame. A live probe of
the field with and without a ttl, a re-recorded cassette, help, NEWS, and the
API reference note. If the probe shows a no-ttl value that is neither a
number, `null`, nor absent, the type rule goes back through the amendment
protocol before it is built.

**Out:** columns for the generation status, the queued requests, the ttl
setting, and the last-used time, which only `lms ps --json` gives. They stay
in the candidate row "list_instances fields and tests" until the REST list
carries them. `list_models()` is unchanged: `detailed = TRUE` already returns
every instance field.

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

- [x] AC1: `list_instances()` returns a double column `remaining_ttl_seconds`
      as its fifth column, after `display_name` and before the configuration
      columns. It holds each instance's value, and `NA_real_` where the field
      is absent or `null`. The column is double in every non-empty frame,
      also one where no instance carries a number. Tests in
      `tests/testthat/test-list-instances.R` assert the position, and assert
      with `expect_identical()` two different values, one of them a whole
      number, both `NA` cases, and the all-`NA` frame, against doubles.
- [x] AC2: A `remaining_ttl_seconds` that is not a number aborts with
      `rlmstudio_bad_response`. With a valid instance first, the message for
      the second instance of the second model holds "`remaining_ttl_seconds`
      of entry 2 of `loaded_instances` in entry 2 of `models` is not a
      number." A test fires the fault once for each form in the `json_forms`
      vector of the tests other than its number and `null` forms, and asserts
      the class and that text. A test asserts that the rule skips a model
      whose type is not in `type`. A test asserts that `list_models()` and
      `lms_server_ready()` accept the body whose only fault is a string
      `remaining_ttl_seconds`.
- [x] AC3: With no instance found, the zero-row frame has the columns `id`,
      `key`, `type`, and `display_name` as character and
      `remaining_ttl_seconds` as double, in that order, asserted by a test.
- [x] AC4: A configuration field named `remaining_ttl_seconds` gives the
      column `config.remaining_ttl_seconds`. A test asserts that
      `remaining_ttl_seconds` holds the instance value and
      `config.remaining_ttl_seconds` holds the configuration value.
- [x] AC5: On the cassette in `tests/testthat/list_instances/`,
      `list_instances()` returns `remaining_ttl_seconds` as a double, with a
      number for the instance loaded with a ttl and, for the other instance,
      the value that a no-ttl instance gives in the live probe. A test
      asserts both values. The header of
      `data-raw/record-list-instances-cassette.R` names the LM Studio version
      and the date of the recording.
- [x] AC6: In the `list_instances()` help (`R/list.R` and
      `man/list_instances.Rd`), the sentence that says `list_instances()`
      does not read `remaining_ttl_seconds` is removed. The Columns section
      and `@return` describe five fixed columns and the double type of
      `remaining_ttl_seconds`, and the clash rule names five fixed column
      names. The help states that the column holds `NA` where the field is
      absent or `null`, what the column holds for an instance loaded with no
      ttl in LM Studio 0.4.26+4, and that no LM Studio version other than
      0.4.26+4 was checked for this field. It has no sentence on the field in
      other versions beyond that one. The sentence on the fields that only
      `lms ps --json` gives names the ttl setting, not the remaining time. A
      `NEWS.md` entry names the new column, the column in the zero-row frame,
      and the `config.` prefix that a configuration field named
      `remaining_ttl_seconds` now takes, and it names LM Studio 0.4.26+4
      where it states what an instance with no ttl holds.
- [x] AC7: `Rscript -e 'devtools::document()'` produces no diff, and
      `Rscript -e 'devtools::test()'` reports no failure and no error.

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number (AC/Task counted
     top-to-bottom). Review reads to fence evidence — tracking-rules "AC fencing". -->

- AC1 → T2, T3
- AC2 → T2, T3
- AC3 → T2, T3
- AC4 → T2, T3
- AC5 → T1, T4
- AC6 → T1, T5
- AC7 → T3, T4, T5

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. Every item opens with its positional label —
     `Tn:` — the item's position counted top-to-bottom, the number Coverage
     cites; an insertion, removal, or reorder renumbers the labels and the
     Coverage lines together. -->

- [x] T1: Live probe. Start the server on port 1234 with the token from
      `~/.lms-token`. Load `google/gemma-3-1b` with `lms load --ttl 600` and
      `text-embedding-nomic-embed-text-v1.5` with no ttl. Read
      `GET /api/v1/models` and `lms ps --json`, and record in one work-log
      line what `remaining_ttl_seconds` holds for each instance. Leave both
      loaded for T4. If the no-ttl value is neither a number, `null`, nor
      absent, stop and amend AC1 and AC2.
- [x] T2: Tests first in `tests/testthat/test-list-instances.R` for AC1 to
      AC4. Update `fixed_columns`, `expect_empty_instances()`, and the other
      tests that expect four columns. See them fail.
- [x] T3: In `R/list.R`, read the field in `list_instances()` with
      `as.double()`, add it to the rows, the frame, and the zero-row frame,
      and add the type rule to `instance_list_fault()`. Run `devtools::test()`.
- [x] T4: Rewrite the header of `data-raw/record-list-instances-cassette.R`:
      the ttl load, the version, the date. Re-record the cassette, update
      the recorded-reply test, then unload both models, start the server on
      1234, and stop it.
- [x] T5: Help in `R/list.R`, `devtools::document()`, a NEWS entry, and the
      model-list note in `cairn/references/lmstudio-api-surface.md`.

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

- 2026-10-19: created by /milestone-plan.
- 2026-10-19: tier check: milestone — adds a column to the result of an exported function.
- 2026-10-19: collision check: absorbs part of the candidate row "list_instances fields and tests" (the ttl column the row names); the four `lms ps` fields stay in the row. M050 and M093 (done) shipped the function and its tests. The type rule works under D-017; no D-entry conflicts. Inbox sweep: 0 open issues, 0 open PRs.
- 2026-10-19: lessons harvested: M086 (pin `rlmstudio.quiet = FALSE` in message tests), M008 (a whole double is invisible on the wire, so test the `as.double()` with a whole number), M083 (end a live probe with a start on 1234 and a stop).
- 2026-10-19: criteria audit (full mode, fresh Opus reader): 9 findings, all fixed. AC1 adds the all-NA frame and a whole-number value. AC2 gives the exact message, drops the vacuous no-instance skip, and names the one body that the other functions accept. AC4 asserts both values. AC5 binds what `list_instances()` returns on the cassette, not the recording. AC6 names the removed sentence, the four-column statements, and the ttl wording. The NEWS entry names three changes. The probe goes first, so a no-ttl value outside the rule is re-planned.
- 2026-10-19: question set: scope — ttl column only, the four `lms ps` fields stay in the candidate row.
- 2026-10-19: question set: column name — `remaining_ttl_seconds`, the server's name.
- 2026-10-19: question set: live probes — yes: start the server on 1234 with `~/.lms-token`, load gemma-3-1b with `--ttl` and the nomic embedding model, read the model list and `lms ps`, re-record the cassette, unload both, stop the server.
- 2026-10-19: plan gate chose the REST field alone over reading `lms ps --json` for the four other fields, because the CLI cannot reach a remote `host` or use a token; falsified by a REST list that carries those fields, or a user who needs them on a local host.
- 2026-10-19: plan gate chose the name `remaining_ttl_seconds` over `ttl_seconds`, because `lms ps` reports a ttl setting in milliseconds that a short name would be read as; falsified by a user who reads the column as the ttl setting.
- 2026-10-19: plan chose the fifth position, before the configuration columns, over appending after them, because the fixed columns then stay together and a configuration field cannot move it; falsified by a user script that indexes configuration columns by position.
- 2026-10-19: implement started on branch m094-list-instances-ttl-column, cut from main at 211b83c.
- 2026-10-19: T1 live probe, LM Studio 0.4.26+4: in `GET /api/v1/models`, gemma-3-1b loaded with `--ttl 600` carried `remaining_ttl_seconds` 590, an integer, about 10 s after the load; the nomic instance loaded with no ttl had no such field at all (absent, not `null`). `lms ps --json` gave `ttlMs` 600000 and `null`. The no-ttl value is absent, so AC1 and AC2 stand. Both models stay loaded for T4.
- 2026-10-19: T2 tests in `test-list-instances.R`: `instance_json()` takes `ttl`, `fixed_columns` holds five names, `expect_empty_instances()` checks a double ttl column; new tests for the column (values 600 and 12.5, absent, null, all-NA frame), the clash, the fault over 6 forms, the type skip, and a third body in the list_models/lms_server_ready test. Run before T3: failures in the new and the five-column tests (10 shown, 27 more), as expected.
- 2026-10-19: T3 in `R/list.R`: `list_instances()` reads the field with `as.double()` (NA_real_ when absent or null) into a fifth column and the zero-row frame; `instance_list_fault()` checks it with `is_json_number()` before `config`. Full `devtools::test()` with the live token: 1 failure, the four-column empty frame in `test-list-args.R` "an unknown type returns the empty frame...", updated to five columns; that file then passes, `test-list-instances.R` passes.
- 2026-10-19: T4: generator header names the CLI loads (gemma with `--ttl 600`, nomic with none), 2026-10-19, LM Studio 0.4.26+4, and the script now stops if gemma has no remaining ttl. Re-recorded the cassette (gemma 213, nomic field absent); no token text in it. The recorded-reply test asserts `c(213, NA_real_)` and passes. Then unloaded both models, started the server on 1234, and stopped it.
- 2026-10-19: T5: `list_instances()` help (intro sentence on the `lms ps` fields now says "ttl setting", Columns section with five fixed columns and the ttl bullet, clash rule, `@return`), the "Malformed model list" section in `R/conditions.R` (three rules, inherited into 9 Rd files), the `instance_list_fault()` comment, a NEWS entry, and the API reference note. `devtools::document()` then gives no further diff; `devtools::test()` with the server stopped: 0 failed, 0 errors, 3 skipped (live). The simple-english hook flagged 10 em-dashes and 2 long sentences in `lmstudio-api-surface.md` that were there before this edit; left as they are.
- 2026-10-19: claim audit: 34 claims read, 5 corrected — R/list.R and man/list_instances.Rd (the column meaning, the intro sentence, the unsupported older-server sentence), NEWS.md (meaning, the abort scope, the no-ttl version), data-raw/record-list-instances-cassette.R (the REST ttl claim now cites the 2026-09-27 probe). Also fixed a lost space in the generator and the stale test name "the two new checks". `test-list-instances.R` passes after the fixes.
- 2026-10-19: re-audit: AC6 (full) — 1 finding on the amendment that replaces "an older server can omit the field" with "other LM Studio versions were not checked": the sentence names no object; narrower "no LM Studio version other than 0.4.26+4 was checked for this field". It also noted that the NEWS no-ttl claim has no version.
- 2026-10-19: re-audit: AC6 (full) — 4 findings on the narrower wording: the clash rule states no type; "the NA case" is ambiguous; nothing requires removing the older-server sentence; the NEWS no-ttl claim has no version bound. This second re-audit line is the stop; AC6 text unchanged on disk until the user picks.
- 2026-10-19: substantive amendment: AC6 narrowed at the user's choice at the stop (user override, "Use the narrower AC6 wording you proposed"): the older-server clause becomes "no LM Studio version other than 0.4.26+4 was checked for this field", with the four second re-audit findings applied (clash rule names five names, both NA cases, no other-version sentence, NEWS names the version). No further reader, since two re-audit lines on AC6 exist. The deliverable already meets it (commit 5c21e96).
- 2026-10-19: all tasks done; status set to review.
- 2026-10-19: review in progress: AC1 to AC6 evidence recorded and ticked; `devtools::check()` and the four reviewers still running (checkpoint, AC7 and findings not yet recorded).
- 2026-10-19: step-7 approval: m094-list-instances-ttl-column approved for merge

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

- AC1 evidence (2026-10-19, `test_file("tests/testthat/test-list-instances.R")` at 0e9acc8, 238 expectations, 0 failed, 0 errors): "remaining_ttl_seconds is the fifth column, a double, NA when absent or null" (2 expectations: names with the column fifth and before `context_length`; `expect_identical` to `c(600, 12.5, NA_real_, NA_real_)` with 600 a whole number, absent and null cases) and "remaining_ttl_seconds is a double column when no instance has a number" (`c(NA_real_, NA_real_)`) pass. T2 log records them failing before T3.
- AC2 evidence (same run): "a remaining_ttl_seconds that is not a number aborts with rlmstudio_bad_response" passes with 24 expectations over the 6 `json_forms` other than number and null (string, boolean, empty array, array, empty object, object), each asserting the class, status 200, "API List Failed", and the exact text "`remaining_ttl_seconds` of entry 2 of `loaded_instances` in entry 2 of `models` is not a number." with a valid instance first. "the remaining_ttl_seconds check skips a model outside `type`" passes (2). The subtest "list_models and lms_server_ready accept the bodies the instance checks reject / remaining_ttl_seconds" passes (3) on the body whose only fault is a string `remaining_ttl_seconds`.
- AC3 evidence (same run): "list_instances returns an empty frame and a message with no instance" (30) and "quiet = TRUE and the rlmstudio.quiet option each stop the message" (54) pass through `expect_empty_instances()`, which asserts the names `id`, `key`, `type`, `display_name`, `remaining_ttl_seconds` in order, `character()` for the first four, and `double()` for the fifth. `test-list-args.R` "an unknown type returns the empty frame and a message, with no abort" passes (6) with the five-column frame.
- AC4 evidence (same run): "a configuration field named remaining_ttl_seconds takes the config. prefix" passes (3): names are the five fixed columns then `config.remaining_ttl_seconds`; `remaining_ttl_seconds` is 300 (instance value) and `config.remaining_ttl_seconds` is 5 (configuration value).
- AC5 evidence (same run): "a recorded model list gives one row per loaded instance" passes (4) on `tests/testthat/list_instances/`, asserting `remaining_ttl_seconds` identical to `c(213, NA_real_)`: a number for gemma, loaded with `--ttl 600`, and NA for nomic, whose field is absent as in the T1 probe. The generator header reads "Recorded:  2026-10-19, LM Studio 0.4.26+4" (`data-raw/record-list-instances-cassette.R:8`).
- AC6 evidence (2026-10-19, `grep` and a read of `man/list_instances.Rd` and `R/list.R` at 0e9acc8): "does not read" matches only the unrelated `lms_unload()` sentence (Rd:151), so the sentence about `remaining_ttl_seconds` is gone. Rd:60 "The first five columns are the fixed columns", Rd:70 "The fifth is a double column", Rd:41 `@return` "the five fixed columns, four character columns and the double column `remaining_ttl_seconds`", Rd:91 clash rule "one of the five fixed column names". Rd:72-76: NA "when the field is absent or `null`", the 0.4.26+4 no-ttl case ("had no such field, so it holds `NA`"), and "No other LM Studio version was checked for this field."; no other sentence on other versions. Rd:53 names "the ttl setting". `NEWS.md:3` names the fifth column, the zero-row frame, `config.remaining_ttl_seconds`, and "In LM Studio 0.4.26+4" for the no-ttl case.
- AC7 evidence (2026-10-19, at 77cef8b after the review fixes): `Rscript -e 'devtools::document()'` left no diff (git status showed no man/ or NAMESPACE change); full `devtools::test()` with the server stopped: 0 failed, 0 errors, 3 skipped (live tests). Earlier live-server run at T3 also had 0 failures after the four-column fix.
- Consistency gate (2026-10-19): `cairn_validate.py` all checks passed; `devtools::check()` at 0e9acc8 code: 0 errors, 0 warnings, 0 notes (2m 27.6s); `pkgdown::check_pkgdown()` no problems; `document()` no diff; NEWS.md has the entry; README.Rmd untouched by the diff; no new top-level files; no principle changed, so no impact report.
- spawned: diff-bug, blame-history, prior-review, ripple
- diff-bug #1: `as.double()` and its test are not load-bearing, since `vapply(..., double(1))` already makes the column double — fix now: removed the redundant coercion; the tests pin the double column, fixed 77cef8b.
- diff-bug #2: comment "jsonlite reads a whole number as an integer" explains a coercion the code does not need — fix now: comment removed with #1, fixed 77cef8b.
- diff-bug #3: ROADMAP row "list_instances fields and tests" still says the field is unread — reject (planned change: post-merge hygiene narrows the row, per Scope Out).
- diff-bug #4: `is_json_number()` accepts `Inf`, so `1e400` lands as `Inf` — follow-up: absorbed into the candidate row "list_instances fields and tests" at hygiene.
- diff-bug #5: NEWS does not say that each configuration column moves one position right — fix now: NEWS sentence added, fixed 77cef8b.
- diff-bug #6: the ttl type-skip test passes through the shared skip — reject (planned change: AC2 requires that test, and it fails if the skip is removed).
- diff-bug #7: the generator's ttl pre-check and recording are two requests — reject (false as a defect: a cassette recorded after the ttl ran out gives NA for gemma, and the recorded-reply test then fails, so it cannot ship unseen).
- diff-bug #8: help, NEWS, and code agree — noted.
- diff-bug #9: uncommitted milestone file — reject (false: committed at 79e7e50).
- blame-history #1: a new abort path on a field that main ignored — reject (planned change: AC2, under D-017).
- blame-history #2: column name and position change for configuration columns — reject (planned change, weighed at the plan gate; NEWS now names the shift).
- blame-history #3: the cassette adds unloaded models and drops `reasoning_budget_message` from gemma's config, and the header does not say so — fix now: header says the list also holds the other models with no instance, fixed 77cef8b. The config field change comes from the newer LM Studio, and no test reads it.
- blame-history #4: M093's help sentence is reversed by AC6, M093 and M050 tests survive — noted.
- blame-history #5: the generator's REST-ttl date and reference-note dates match the records — noted.
- prior-review #1: ROADMAP row still says the field is unread — reject (planned change: hygiene narrows the row).
- prior-review #2: `R/list.R` line of 84 characters — reject (style; `air format --check` also flags the main versions of these files).
- prior-review #3: two blank lines before a test section header — reject (style; the file already uses that pattern before its other section headers).
- ripple #1: `data-raw/README.md:26` loads gemma with no ttl, so the recorder stops — fix now: `--ttl 600` added and the stop condition named, fixed 77cef8b.
- ripple #2: ROADMAP candidate row contradicts the column — reject (planned change: hygiene narrows the row).
