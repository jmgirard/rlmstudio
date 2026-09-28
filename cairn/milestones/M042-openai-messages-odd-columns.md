<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M042: The OpenAI chat function reads each row of an array or non-vector messages column on its own

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
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
- [ ] AC2: In `lms_chat_openai()`, a data-frame column that is neither an
  atomic vector nor a list counts as not empty in each row. Examples are an
  environment, a formula, a symbol, a call, an S4 object, an external
  pointer, an expression vector, and a function. This holds for a column of
  `messages` and for a column of a data-frame column. The call gives no R
  warning for a column of these kinds. In a frame that breaks no other
  `messages` rule and holds no function, a column of each of these kinds
  other than a function aborts with the value-fault header and the
  jsonlite-write detail. A function column in a row that is otherwise `NA`
  aborts with the function detail.
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
- AC2 → T2
- AC3 → T3
- AC4 → T3
- AC5 → T4
- AC6 → T5

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive change is amend-via-gate. -->

- [x] T1: In `empty_rows()` (`R/utils-args.R:718`), read a column with a
  `dim` attribute row by row, through the cells whose first index is the
  row. Keep the result one value per row. Add probes to
  `tests/testthat/test-arg-guards.R` for the three AC1 cases, built with
  `$<-`, because `data.frame()` recycles an array to its length. Add a
  probe for a four-dimensional list column with one `NULL` in a row. Add a
  probe for a three-dimensional list column with `NULL` in each cell of
  row 2. Every other column of that row is `NA`, and the probe expects the
  empty-row detail. Add a probe for a three-dimensional column inside a
  data-frame column. Add a
  two-dimensional matrix column as a control that keeps its result. Add a
  one-dimensional atomic column and a one-dimensional list column as
  controls whose result does not change. Revert the fix in a scratch copy
  and make sure that the new probes go red. Run `devtools::test()`.
- [x] T2: In `empty_rows()`, replace the function branch with one branch
  for a column that is neither an atomic vector nor a list. Update the
  comment above the function. Add probes for an environment, a formula, a
  symbol, a call, an S4 object, an external pointer, and an expression
  vector column. Put each one in a row that is otherwise `NA`. Add one such
  column inside a data-frame column. Build each probe with `$<-` where it
  accepts the value, else with `structure()`. Each probe
  asserts the value-fault header, the jsonlite-write detail, and no
  warning. Add a probe for a function column in a row that is otherwise
  `NA`, which asserts the function detail. Revert the branch in a scratch
  copy and make sure that each probe other than the function probe goes red. Run `devtools::test()`.
- [x] T3: Edit the `messages` help in `R/chat.R`. Replace the empty-row
  sentence at lines 290-291 for AC4. Replace the list-matrix sentence at
  lines 300-301 for AC3. Add a test that sends the AC3 example row and
  compares the request body with the sent form in the help. Run
  `devtools::document()` and `devtools::test()`.
- [x] T4: Join the `@aliases` tag at `R/conditions.R:257` onto one line.
  Run `devtools::document()` and make sure that it prints no warning.
- [x] T5: Add the NEWS entry. Run `devtools::document()`,
  `devtools::test()`, and `devtools::check()` with the API token (see the
  M009 lesson on the vignette build). Give a reason for each NOTE in the
  work log.

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

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

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
