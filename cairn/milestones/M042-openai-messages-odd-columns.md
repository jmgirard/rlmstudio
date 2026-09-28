<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M042: The OpenAI chat function reads each row of an array or non-vector messages column on its own

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP4   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — it changes which error an exported function gives for a `messages` value, and its help   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m042-openai-messages-odd-columns   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

`lms_chat_openai()` judges each row of a `messages` data frame by the
cells of that row, for an array column or a column that is not a vector.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** `empty_rows()` in `R/utils-args.R:718` decides the empty-row rule.
Today it calls `is.na()` on each column. For a column with three or more
dimensions, `is.na()` gives one value per cell, and the row test recycles
it. So a row with one empty cell can count as empty. For a column that is
not a vector, such as an environment, `is.na()` warns before the trial
write refuses the value. This milestone reads such columns row by row and
without `is.na()`. The help at `messages` says how a list-matrix column is
sent. The `@aliases` tag at `R/conditions.R:257` goes onto one line. NEWS
and tests say so. Three ROADMAP candidate rows close with this milestone.
Two are M041 review rows, on `empty_rows()` and on list-matrix cells. One
is the M036 review row on the `@aliases` warning.

**Out:** A frame built by hand with `structure()` can hold an array
column whose first extent is not the row count. It can also hold a `NULL`
column. `data.frame()` and `$<-` cannot build either, so no row is added. A change
to what is sent for a list-matrix column: the plan gate kept the M041
choice to send it as jsonlite writes it.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [x] AC1: In `lms_chat_openai()`, if the first extent of a data-frame
  column with a `dim` attribute equals the row count, the empty-row rule
  reads that column row by row. For each row, the rule reads the cells
  whose first index is that row. If each of those cells is empty, the
  column is empty in that row. This holds for a column of
  `messages` and for a column of a data-frame column. Tests cover three
  cases before the server probe. In case 1, a list column with three
  dimensions holds one `NULL` cell and other cells that are not empty in
  row 2. Every other column of row 2 is `NA`. The call aborts with the
  inner `dim` detail and not the empty-row detail. In case 2, an atomic
  column with three dimensions holds one `NA` cell in row 2. Every other
  column of row 2 is `NA`. The call passes every `messages` rule and
  reaches the server probe. In case 3, the same frame has `NA` in every cell of row 2.
  The call aborts with the empty-row detail.
- [x] AC2: A data-frame column for which `is.atomic()` and `is.list()` are
  both FALSE counts as not empty in each row of `empty_rows()`, and
  `empty_rows()` gives no R warning for it. This holds at the top level
  of `messages` and inside a data-frame column. The domain is the twelve
  column kinds that the test "empty_rows() finds no empty row in a column
  that is not a vector" builds:

  - an environment
  - a formula
  - a symbol
  - a call
  - an S4 object of a class with one numeric slot
  - a reference-class object
  - an external pointer
  - an expression vector
  - a function
  - a class generator
  - a class definition with a slot
  - a class definition with no slot

  Each kind sits at both depths in a one-row frame whose other column is
  `NA`. A three-row formula column is the thirteenth case. For each,
  `empty_rows()` returns all `FALSE` with no warning.

  In `lms_chat_openai()`, for each column kind that the test "a column
  that is not a vector is not empty and gives no warning" builds, in a
  frame whose other cells are `NA`, the call aborts before the server
  probe. The abort carries the value-fault header and the jsonlite-write
  detail, with no R warning. The kinds are:

  - an environment, a symbol, a call, and an expression vector, each with
    no `class` attribute
  - a formula made with `~`
  - an object of an S4 class that `methods::setClass()` defines with one
    numeric slot
  - a reference-class object
  - an external pointer
  - a symbol inside a data-frame column

  A function column in such a frame, at the top level or inside a
  data-frame column, aborts with the function detail, with no R warning.

  For any other column that is neither an atomic vector nor a list, this
  criterion promises only the first paragraph. The later rules and the
  trial write decide the call. AC2 does not state their result.
- [x] AC3: The `messages` help of `lms_chat_openai()` says that jsonlite
  does not unbox a value inside a list-matrix cell, at any depth in a list,
  unless `jsonlite::unbox()` wraps it. A data frame in a cell is sent as an
  array of objects whose values are not boxed. So a length-one atomic cell
  is sent as a one-element array, such as `["a"]`, and a `NULL` cell is
  sent as `null`. It gives the sent form of one example row. The
  `messages` element of the request body for that example is an array that
  holds that form alone. `man/lms_chat_openai.Rd` matches after
  `devtools::document()`.
- [x] AC4: The `messages` help replaces its sentence on matrix and
  data-frame columns in empty rows. The new text says two things. If each
  cell of a row is empty in a column with a `dim` attribute of any length,
  or in a data-frame column, that column counts as empty in the row. A
  column that is neither an atomic vector nor a list, such as an
  environment, never counts as empty.
- [x] AC5: The `@aliases` tag at `R/conditions.R:257` sits on one line.
  `devtools::document()` prints no warning and changes no file under `man/`.
- [x] AC6: NEWS.md has one entry for the changes in AC1 and AC2, with no
  milestone number. `devtools::test()` gives 0 failures. `devtools::check()`
  gives 0 errors and 0 warnings.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T1
- AC2 → T2, T6, T7, T8
- AC3 → T3
- AC4 → T3
- AC5 → T4
- AC6 → T5, T7, T8

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive change is amend-via-gate. -->

- [x] T1: `empty_rows()` reads a `dim` column row by row, with probes for AC1 (revert results in the work log).
- [x] T2: `empty_rows()` treats a non-atomic, non-list column as never empty, with a probe per AC2 kind.
- [x] T3: The `messages` help sentences for AC3 and AC4, and a test that sends the AC3 example row.
- [x] T4: The `@aliases` tag at `R/conditions.R:257` on one line.
- [x] T5: The NEWS entry, then `document()`, `test()`, and `check()`.
- [x] T6: Return-1 work: an `empty_rows()` test, class-definition probes, NEWS narrowed, one candidate row.
- [x] T7: Pass-2 items: NEWS on a 3-D `NA`, a sent-form test, a reference-class probe, two candidate rows.
- [x] T8: Replace the NEWS.md sub-item with the RR01 section 4 text, and change "refuses it later" to
  "judges it later" in the `empty_rows()` comment. Run `devtools::test()` and `devtools::check()`.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-09-27: created by /milestone-plan.
- 2026-09-27: criteria audit (full mode, fresh [O] reader) returned 14 items. It gave 8 clear fixes, all applied, and 4 items with no finding. Two judgment calls were settled by narrowing: hand-built frames are out of scope, and AC2 says no warning in place of no `is.na()` call.
- 2026-09-27: plan gate chose to state the boxed list-matrix cells in the help over unboxing them or refusing the column. M041 chose to send the column, and the fault is only in the help. Falsified by a server or model that misreads a one-element array in a list-matrix field.
- 2026-09-27: plan gate chose to fold the `@aliases` fix into this milestone over a separate trivial commit. AC5 can then require a `document()` run with no warning. No behavior falsifies it, because it is a scheduling choice.
- 2026-09-27: plan committed while the second audit of the revised criteria (full mode, same [O] reader) still runs. Its findings land as a gated amendment before implement starts.
- 2026-09-27: implement started on branch m042-openai-messages-odd-columns. The second audit's findings never reached the file, so a fresh [O] reader re-runs it before T1.
- 2026-09-27: T4 done. The `@aliases` tag is on one line, and `devtools::document()` printed no warning and changed no file under `man/`.
- 2026-09-27: second criteria audit (full mode, fresh [O] reader) returned 11 items. Minor task edits applied: T1 builds its frames with `$<-` and adds a four-dimensional list probe and an all-`NULL` list-array row. T2 adds an expression vector, rows that are otherwise `NA`, a nested column, and a constructor for each probe.
- 2026-09-27: implement gate amended AC2 (expression vector, nested columns), AC3 (unbox and nested values, the `messages` element compared), AC5 (`man/` in place of `git status`), and AC6 (the NOTE reason moves to T5, as a record act).
- re-audit: AC2 (full) — the claim was false for an S4 class definition, which jsonlite writes with a warning, and it ignored rules that win first. The user adopted a narrowed text.
- re-audit: AC3 (full) — "at any depth" was false for a data frame in a cell, and the `messages` element is an array of rows. The user adopted an amended text.
- re-audit: AC5 (full) — nothing
- re-audit: AC6 (full) — nothing
- 2026-09-27: T2's revert step now expects each probe other than the function probe to go red, because a revert to the old function branch keeps that probe green.
- 2026-09-27: T1 done. `empty_rows()` reads a `dim` column through `apply()` when its first extent is the row count. With the old `empty_rows()` swapped in, cases 1 and 2, the 4-D list probe, and the nested one-`NA` probe gave the empty-row detail. The three all-empty probes and the controls gave the same result before and after, so they cannot go red on revert. `devtools::test()`: 0 failures.
- 2026-09-27: T2 done. `empty_rows()` treats a column that is neither atomic nor a list as never empty. Before the branch change, all eight non-function probes went red on the `is.na()` warning, and the function probe stayed green. `devtools::test()`: 0 failures.
- 2026-09-27: T3 done. The help's list-matrix text and example were written from a jsonlite run of the same rows. A new test sends the help example and a second row with `unbox()`, a nested list, and a data frame in cells, and compares each `messages` element with JSON text stated in the test. `devtools::test()`: 0 failures.
- 2026-09-27: T5 done. NEWS.md has one entry for the AC1 and AC2 changes. `devtools::document()` changed nothing, `devtools::test()` gave 0 failures, and `devtools::check()` with the API token gave 0 errors, 0 warnings, and 0 notes, so no NOTE needs a reason.
- claim audit: 31 claims read, 5 corrected — tests/testthat/test-arg-guards.R, R/utils-args.R, R/chat.R, man/lms_chat_openai.Rd
- 2026-09-27: the claim reader re-read the five corrections and found each correct. `devtools::test()` after them: 0 failures. Status set to review.
- 2026-09-27: review returned the milestone to in-progress (defect return 1). AC2 fails: an S4 class-definition column warns from jsonlite and reaches the server probe. Proposed fix-now items O2 and O5 are in the Review section.
- 2026-09-27: implement resumed. The question gate chose to narrow AC2 over a new refusal for S4 columns.
- re-audit: AC2 (full) — the proposed narrowing was false for a class definition with no slots, which aborts at the trial write. "An S4 object that jsonlite can write" was unbounded. The reader offered a text that bounds the exception to a class definition with a slot and asked for an `empty_rows()`-level test and a NEWS fix. This is the second AC2 re-audit, so the wording goes to the user.
- 2026-09-27: the user adopted the reader's AC2 text verbatim. AC2 now binds `empty_rows()` for the no-warning clause and excludes a class definition with a slot from the abort clause. T6 added for the review return work, and Coverage maps AC2 to T2 and T6.
- 2026-09-27: T1 and T2 text compressed to bring the plan-owned body under the 150-line cap.
- 2026-09-27: T6 done. A direct `empty_rows()` test covers twelve kinds at top level and nested, and it gave 26 failures with the old function branch swapped in. A probe pins the slotted and slotless class-definition columns. The function probe now checks for no warning and has a nested case. NEWS narrowed, and a candidate row added. `devtools::test()`: 11736 expectations, 0 failures. `devtools::check()`: 0 errors, 0 warnings, 0 notes.
- claim audit: 18 claims read, 0 corrected — NEWS.md, tests/testthat/test-arg-guards.R
- 2026-09-27: the claim reader noted that `empty_rows()` returns `logical(0)` for a zero-length column in a one-row frame built by hand. The call still aborts at the trial write, and hand-built frames are Scope Out. Status set to review.
- 2026-09-27: review pass 2 returned the milestone to in-progress (defect return 2). AC2 fails again: a classed non-vector column that jsonlite can write is sent, where AC2 says it aborts. This is AC2's second failure by the same kind of cause, a jsonlite write the text did not foresee, so the thrash rule's wrong-approach trigger fires. The alternative on record is the one the implement gate set aside: refuse such columns in code.
- 2026-09-27: implement resumed after defect return 2. The question gate chose a review brief for the AC2 repair and chose to do the pass-2 review items now.
- 2026-09-27: T7 done. NEWS qualifies the 3-D `NA` sentence and quotes the empty-row error. A new test pins the sent form of an `NA` in a 3-D numeric, logical, and character column. The AC2 whole-call test has a reference-class probe. The O3 and O4 candidate rows are in ROADMAP, with P2 in the O4 row. `devtools::test()`: 11745 expectations, 0 failures.
- 2026-09-27: blocked on RB01. The brief is committed on the milestone branch, not on main, because the branch holds the current M042 tracking and main's copy is behind it.
- 2026-09-27: RR01 ingested from a Fable subagent. Triage: recommendation 1 apply (AC2 through the amendment gate, plus T8), 2 apply (the class-definition test and its row stay), 3 scheduled by merging into the class-definition candidate row, 4 scheduled as a candidate row, 5 to 7 rejected for the reasons RR01 gives. RB01 and RR01 moved to the archive. Status back to in-progress.
- 2026-09-27: the AC2 amendment gate adopted the RR01 section 3 text verbatim. It narrows the criteria set. No re-audit reader ran, because AC2 already has two re-audit lines, so the user decided the wording. The Tasks section was compressed to keep the plan-owned body under 150 lines.
- 2026-09-27: T8 done. The NEWS sub-item now carries the RR01 text, with its one trailing condition moved to the front, and the `empty_rows()` comment says "judges". `devtools::document()` changed no file. `devtools::test()`: 11745 expectations, 0 failures. `devtools::check()` with the API token: 0 errors, 0 warnings, 0 notes.
- claim audit: 48 claims read, 2 corrected — NEWS.md
- 2026-09-27: the claim reader re-read NEWS.md line 4 and found both corrections true. A non-vector column never gave the empty-row error on main either, so the sub-item now says only the warning is gone. A slotted class definition is named as sent. The reader's optional tightening for an S4 object that contains a basic type was not applied, because the line's scope already excludes atomic columns. Status set to review.

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

- 2026-09-27 (RR01): AC2 is repaired by narrowing it. Its abort clause names only the kinds that two tests build, and a last paragraph says AC2 promises nothing more for another non-vector column. jsonlite judges a non-vector value by its class attribute alone, so only a kind with no class set by hand has a fixed outcome. A code refusal for data-frame columns alone was rejected, because the same classed value in a list message is still sent. A refusal over both forms is a candidate row. Dropping the abort clause was rejected, because it loses the record of what the user now sees.

## Review
<!-- owner: review · exclusive -->

Sync: the branch contains `origin/main` (b828540), so no merge was needed. The review ran on 2026-09-27.

- AC1 evidence: a scratch script called `lms_chat_openai()` on port 1 and counted warnings. Case 1 (3-D list, one `NULL` in row 2) aborted with the list-`dim` detail. Case 2 (3-D atomic, one `NA`) reached the server probe. Case 3 (all `NA` in row 2) aborted with the empty-row detail. Case 2 inside a data-frame column reached the server probe. No call warned. The test "a column with a dim attribute is read row by row" passed 27 expectations. They include a no-match check on the other detail and a zero probe count.
- AC2 evidence: the same script gave the value-fault header and the jsonlite-write detail, with 0 warnings, for eight columns. They are an environment, a formula, a symbol, a call, an S4 object, an external pointer, an expression vector, and a nested symbol. A function column in an otherwise-`NA` row gave the function detail. The test "a column that is not a vector is not empty and gives no warning" passed.
- AC3 evidence: `R/chat.R` and `man/lms_chat_openai.Rd` carry the four sentences AC3 names and the example row with its sent form. A jsonlite write of that row with the package options gave `[{"role":"user","content":"hi","tags":[["a"],null,{"k":["v"]}]}]`. That matches the help. The test "a list-matrix column is sent with its cells boxed" compares the sent `messages` element with a one-element array of that form. It passed. `devtools::document()` changed no file.
- AC4 evidence: the old sentence on matrix and data-frame columns is gone. The new text states the empty-row rule for a column with a `dim` attribute of any length and for a data-frame column. It states that a column that is neither an atomic vector nor a list never counts as empty. It adds the qualifier "whose first extent is the row count". That qualifier matches AC1 and the Out scope on hand-built frames.
- AC5 evidence: `R/conditions.R:257` holds the `@aliases` tag on one line. `devtools::document()` printed only its two info lines and no warning. `git status` showed no change under `man/`.
- AC6 evidence: NEWS.md has one new entry, with a sub-item, for the AC1 and AC2 changes. The added lines hold no milestone number. `devtools::test()` gave 11678 expectations, 0 failures, 0 errors, and 0 skips. `devtools::check()` with the API token gave 0 errors, 0 warnings, and 0 notes.
- Consistency gate: `cairn_validate.py` exited 0. No DESIGN principle changed, so `cairn_impact` was skipped. `devtools::document()` gave no diff. The diff does not touch README.Rmd, and the repo has no pkgdown site. No new top-level file.
- AC2 failed at independent review, so its tick is withdrawn. A column that holds an S4 class definition (`methods::getClass()`) is neither an atomic vector nor a list. The call gives the jsonlite warning "collapse=FALSE called for named list." and reaches the server probe. AC2 promises no warning and a value-fault abort for an S4 object. Confirmed by a rerun of the reviewer's input.

Independent review (three fresh readers). The [S] history reader found no regression and no contradicted decision. The [S] prior-review reader found that the diff closes M041 findings O1, O2, and O4 and the M036 `@aliases` row as triaged, with no regression. GitHub has no PR review comments. The [O] diff reader reported nine findings, ranked. Each disposition is proposed and goes to the maintainer at the next gate.

- O1 (AC2 fails for an S4 class definition, and NEWS.md:4 says the same false thing): return to implement.
- O2 (NEWS.md:3 says a list column of three or more dimensions aborts with the list-`dim` error, but a row empty in every column gets the empty-row error first): fix now.
- O3 (a numeric array or matrix column sends `NA` as the string `"NA"`, and the branch lets more such values through): follow-up candidate, because the 2-D case predates the branch.
- O4 (an n-by-0 matrix column counts as empty in each row, though jsonlite writes `[]`): follow-up candidate, pre-existing on main.
- O5 (no probe for a function column inside a data-frame column, which AC2 covers): fix now.
- O6 (the AC3 test states the help example as a literal, so help and test can drift): reject, a known limit of a stated-form test.
- O7 (no one-row or mixed-row-count nested probe; the reviewer checked both by hand): reject, coverage only.
- O8 (a first extent that differs from the row count mis-recycles): reject, Scope Out.
- O9 (the non-vector change is a sub-bullet of the array bullet): reject, AC6 asks for one entry.

Second pass, 2026-09-27, after the AC2 amendment and T6. The branch still contains `origin/main`, and no PR exists.

- AC1 evidence (pass 2): the probe script gave the same four results as pass 1, with 0 warnings. The row-by-row test passed 27 expectations.
- AC2 evidence (pass 2): the eight kinds from pass 1 and a reference-class object gave the value-fault header and the jsonlite-write detail, with 0 warnings. A class definition with no slot gave the same abort. A class definition with a slot gave the jsonlite warning and reached the server probe, which is the one exception AC2 allows. A function column, top level and nested, gave the function detail with 0 warnings. A direct `empty_rows()` call gave `FALSE` with 0 warnings for an environment, a symbol, a slotted class definition, and a function. The three AC2 tests passed 29, 49, and 6 expectations.
- AC3 to AC5 evidence (pass 2): the jsonlite write of the help row again matched the help, and the boxed-cells test passed 4 expectations. `devtools::document()` printed no warning and changed no file. `R/conditions.R:257` holds the `@aliases` tag on one line.
- AC6 evidence (pass 2): NEWS.md keeps one entry for AC1 and AC2, now with the class-definition exception and the empty-row order. The added lines hold no milestone number. `devtools::test()` gave 11736 expectations, 0 failures, 0 errors, and 0 skips. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- Consistency gate (pass 2): `cairn_validate.py` exited 0, and `devtools::document()` gave no diff. The other profile checks are unchanged from pass 1.
- AC2 failed at the pass-2 review, so its tick is withdrawn. A column that is neither an atomic vector nor a list but carries an S3 class jsonlite can write passes the trial write. Three inputs reached the server probe: an environment with class `"POSIXt"`, a call with class `"function"`, and an expression vector with class `"NULL"`. AC2 says every such column aborts, with a slotted class definition as the one exception. Confirmed by a rerun.

Pass-2 independent review. The [S] history reader and the [S] prior-review reader found nothing. The [O] diff reader reported nine findings, ranked. Proposed dispositions go to the maintainer at the next gate.

- P1 (AC2, NEWS.md:4, and the `empty_rows()` comment claim that every classed non-vector column aborts): return to implement.
- P2 (an array with a zero extent and three or more dimensions now refuses a row, where main passed the frame, so O4 is partly new on this branch): fold into the O4 candidate row.
- P3 (NEWS.md:3 announces a 3-D numeric column with one `NA` as sent, but jsonlite sends that `NA` as `"NA"`): qualify the NEWS sentence, with O3 as its candidate row.
- P4 (a sparse `Matrix` column now skips the empty-row rule and gets the jsonlite-write error first): reject, it matches "never counts as empty".
- P5 (the class-definition test asserts jsonlite's warning text): reject, the test pins current jsonlite behavior on purpose.
- P6 (no whole-call probe for a reference-class object): fix now.
- P7 (some probes stay green on revert): reject, the work log records which ones go red.
- P8 (the O3 and O4 candidate rows are not written yet): fix at the gate once O3 and O4 are accepted.
- P9 (NEWS.md:3 paraphrases the empty-row error text): fix now.

Third pass, 2026-09-28, after the RR01 amendment of AC2 and tasks T7 and T8. The branch contains `origin/main` (b828540), and no PR exists.

- AC1 evidence (pass 3): a probe script called `lms_chat_openai()` on port 1. Case 1 gave the list-`dim` detail, case 2 reached the server probe, case 3 gave the empty-row detail, and case 2 inside a data-frame column reached the server probe. No call warned. The row-by-row test passed 27 expectations.
- AC2 evidence (pass 3): each of the nine whole-call kinds AC2 lists gave the value-fault header and the jsonlite-write detail with 0 warnings. The kinds are an environment, a symbol, a call, an expression vector, a formula, an S4 object, a reference-class object, an external pointer, and a symbol in a data-frame column. A function column, top level and nested, gave the function detail with 0 warnings. The test "empty_rows() finds no empty row in a column that is not a vector" passed 49 expectations, which cover the twelve kinds at two depths and the three-row formula. The test "a column that is not a vector is not empty and gives no warning" passed 32 expectations.
- AC3 evidence (pass 3): a jsonlite write of the help row with the package options gave `[{"role":"user","content":"hi","tags":[["a"],null,{"k":["v"]}]}]`, which matches `R/chat.R:313` and `man/lms_chat_openai.Rd:69`. The help lines at `R/chat.R:307-310` carry the unbox, data-frame, one-element-array, and `null` sentences. The boxed-cells test passed 4 expectations.
- AC4 evidence (pass 3): `R/chat.R:290-295` states the rule for a column with a `dim` attribute of any length and for a data-frame column, and says a column that is neither an atomic vector nor a list never counts as empty.
- AC5 evidence (pass 3): `R/conditions.R:257` holds the `@aliases` tag on one line. `devtools::document()` printed no warning and changed no file.
- AC6 evidence (pass 3): the NEWS.md diff adds one top-level entry, with one sub-item, and no milestone number. `devtools::test()` gave 11745 expectations, 0 failures, 0 errors, and 0 skips. `devtools::check()` with the API token gave 0 errors, 0 warnings, and 0 notes.
- Consistency gate (pass 3): `cairn_validate.py` exited 0, coverage included. No DESIGN principle changed, so `cairn_impact` was skipped. `devtools::document()` gave no diff. The diff touches no README.Rmd, the repo has no pkgdown site, and the only new files are the archived RB01 and RR01 under `cairn/`.

Pass-3 independent review. The [S] history reader found no regression. The [S] prior-review reader found every pass-1 and pass-2 fix-now item landed and no rejected item back, and GitHub has no PR review comments. The [O] diff reader found no criterion failing and reported nine findings, ranked. Proposed dispositions go to the maintainer at the gate.

- Q1 (NEWS.md:4 says a non-vector column "still" never counts as empty, but on main a `Matrix::Matrix()` column reached `is.na()` and then stopped with a plain `rowSums()` error, confirmed by a rerun): fix now, drop "still".
- Q2 (the `empty_rows()` comment says `is.na()` warns on such a column, but a class with an `is.na()` method, such as a Matrix class, does not warn): fix now, say "warns on most such columns".
- Q3 (the three-row formula case in the `empty_rows()` test has no `expect_no_warning()`, though AC2 names it): fix now.
- Q4 (the help's "at any depth in a list" can mislead for a data frame inside a list in a cell): reject, the text matches AC3 and the case needs a nested data frame.
- Q5 (NEWS "an S4 object that `new()` makes" overlaps with the class-definition sentence): reject, the next sentence names the exception.
- Q6 (NEWS does not say which value rule runs first): reject, "the later rules decide the call" covers it.
- Q7 (Air would re-wrap one new entry at `tests/testthat/test-arg-guards.R:1586-1587`): fix now, that hunk only. The other Air drift is on main.
- Q8 (`apply()` is slower than `rowSums()`, 0.069 s against 0.001 s at 200,000 rows): reject, negligible.
- Q9 (a classed array whose `is.na()` drops `dim` would make `apply()` error): reject, no real class found.
