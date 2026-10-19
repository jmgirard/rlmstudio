<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M094: list_instances remaining ttl column

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
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

- [ ] AC1: `list_instances()` returns a double column `remaining_ttl_seconds`
      as its fifth column, after `display_name` and before the configuration
      columns. It holds each instance's value, and `NA_real_` where the field
      is absent or `null`. The column is double in every non-empty frame,
      also one where no instance carries a number. Tests in
      `tests/testthat/test-list-instances.R` assert the position, and assert
      with `expect_identical()` two different values, one of them a whole
      number, both `NA` cases, and the all-`NA` frame, against doubles.
- [ ] AC2: A `remaining_ttl_seconds` that is not a number aborts with
      `rlmstudio_bad_response`. With a valid instance first, the message for
      the second instance of the second model holds "`remaining_ttl_seconds`
      of entry 2 of `loaded_instances` in entry 2 of `models` is not a
      number." A test fires the fault once for each form in the `json_forms`
      vector of the tests other than its number and `null` forms, and asserts
      the class and that text. A test asserts that the rule skips a model
      whose type is not in `type`. A test asserts that `list_models()` and
      `lms_server_ready()` accept the body whose only fault is a string
      `remaining_ttl_seconds`.
- [ ] AC3: With no instance found, the zero-row frame has the columns `id`,
      `key`, `type`, and `display_name` as character and
      `remaining_ttl_seconds` as double, in that order, asserted by a test.
- [ ] AC4: A configuration field named `remaining_ttl_seconds` gives the
      column `config.remaining_ttl_seconds`. A test asserts that
      `remaining_ttl_seconds` holds the instance value and
      `config.remaining_ttl_seconds` holds the configuration value.
- [ ] AC5: On the cassette in `tests/testthat/list_instances/`,
      `list_instances()` returns `remaining_ttl_seconds` as a double, with a
      number for the instance loaded with a ttl and, for the other instance,
      the value that a no-ttl instance gives in the live probe. A test
      asserts both values. The header of
      `data-raw/record-list-instances-cassette.R` names the LM Studio version
      and the date of the recording.
- [ ] AC6: In the `list_instances()` help (`R/list.R` and
      `man/list_instances.Rd`), the sentence that says `list_instances()`
      does not read `remaining_ttl_seconds` is removed. The Columns section,
      the clash rule, and `@return` describe five fixed columns and the double
      type of `remaining_ttl_seconds`. The help states the `NA` case, what
      the column holds for an instance loaded with no ttl in LM Studio
      0.4.26+4, and that an older server can omit the field. The sentence on
      the fields that only `lms ps --json` gives names the ttl setting, not
      the remaining time. A `NEWS.md` entry names the new column, the column
      in the zero-row frame, and the `config.` prefix that a configuration
      field named `remaining_ttl_seconds` now takes.
- [ ] AC7: `Rscript -e 'devtools::document()'` produces no diff, and
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
- [ ] T2: Tests first in `tests/testthat/test-list-instances.R` for AC1 to
      AC4. Update `fixed_columns`, `expect_empty_instances()`, and the other
      tests that expect four columns. See them fail.
- [ ] T3: In `R/list.R`, read the field in `list_instances()` with
      `as.double()`, add it to the rows, the frame, and the zero-row frame,
      and add the type rule to `instance_list_fault()`. Run `devtools::test()`.
- [ ] T4: Rewrite the header of `data-raw/record-list-instances-cassette.R`:
      the ttl load, the version, the date. Re-record the cassette, update
      the recorded-reply test, then unload both models, start the server on
      1234, and stop it.
- [ ] T5: Help in `R/list.R`, `devtools::document()`, a NEWS entry, and the
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
