<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M042: The OpenAI chat function reads each row of an array or non-vector messages column on its own

- **Status:** planned   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP4   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — it changes which error an exported function gives for a `messages` value, and its help   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** —   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

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

- [ ] AC1: In `lms_chat_openai()`, if the first extent of a data-frame
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
  pointer, and a function. The call gives no R warning for such a column.
  A column of this kind other than a function aborts with the value-fault
  header and the jsonlite-write detail. A function column in a row that is
  otherwise `NA` aborts with the function detail.
- [ ] AC3: The `messages` help of `lms_chat_openai()` says that jsonlite
  does not unbox a list-matrix cell. So a length-one atomic cell is sent as
  a one-element array, such as `["a"]`, and a `NULL` cell is sent as
  `null`. It gives the sent form of one example row. The request body of
  that example has that form. `man/lms_chat_openai.Rd` matches after
  `devtools::document()`.
- [ ] AC4: The `messages` help replaces its sentence on matrix and
  data-frame columns in empty rows. The new text says two things. If each
  cell of a row is empty in a column with a `dim` attribute of any length,
  or in a data-frame column, that column counts as empty in the row. A
  column that is neither an atomic vector nor a list, such as an
  environment, never counts as empty.
- [ ] AC5: The `@aliases` tag at `R/conditions.R:257` sits on one line.
  `devtools::document()` prints no warning and leaves `git status` clean.
- [ ] AC6: NEWS.md has one entry for the changes in AC1 and AC2, with no
  milestone number. `devtools::test()` gives 0 failures. `devtools::check()`
  gives 0 errors and 0 warnings. The Review section gives a reason for each
  NOTE.

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

- [ ] T1: In `empty_rows()` (`R/utils-args.R:718`), read a column with a
  `dim` attribute row by row, through the cells whose first index is the
  row. Keep the result one value per row. Add probes to
  `tests/testthat/test-arg-guards.R` for the three AC1 cases. Add probes for
  a four-dimensional atomic column with one `NA` in a row, and for a
  three-dimensional column inside a data-frame column. Add a
  two-dimensional matrix column as a control that keeps its result. Add a
  one-dimensional atomic column and a one-dimensional list column as
  controls whose result does not change. Revert the fix in a scratch copy
  and make sure that the new probes go red. Run `devtools::test()`.
- [ ] T2: In `empty_rows()`, replace the function branch with one branch
  for a column that is neither an atomic vector nor a list. Update the
  comment above the function. Add probes for an environment, a formula, a
  symbol, a call, an S4 object, and an external pointer column. Each probe
  asserts the value-fault header, the jsonlite-write detail, and no
  warning. Add a probe for a function column in a row that is otherwise
  `NA`, which asserts the function detail. Revert the branch in a scratch
  copy and make sure that the probes go red. Run `devtools::test()`.
- [ ] T3: Edit the `messages` help in `R/chat.R`. Replace the empty-row
  sentence at lines 290-291 for AC4. Replace the list-matrix sentence at
  lines 300-301 for AC3. Add a test that sends the AC3 example row and
  compares the request body with the sent form in the help. Run
  `devtools::document()` and `devtools::test()`.
- [ ] T4: Join the `@aliases` tag at `R/conditions.R:257` onto one line.
  Run `devtools::document()` and make sure that it prints no warning.
- [ ] T5: Add the NEWS entry. Run `devtools::document()`,
  `devtools::test()`, and `devtools::check()` with the API token (see the
  M009 lesson on the vignette build).

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-09-27: created by /milestone-plan.
- 2026-09-27: criteria audit (full mode, fresh [O] reader) returned 14 items. It gave 8 clear fixes, all applied, and 4 items with no finding. Two judgment calls were settled by narrowing: hand-built frames are out of scope, and AC2 says no warning in place of no `is.na()` call.
- 2026-09-27: plan gate chose to state the boxed list-matrix cells in the help over unboxing them or refusing the column. M041 chose to send the column, and the fault is only in the help. Falsified by a server or model that misreads a one-element array in a list-matrix field.
- 2026-09-27: plan gate chose to fold the `@aliases` fix into this milestone over a separate trivial commit. AC5 can then require a `document()` run with no warning. No behavior falsifies it, because it is a scheduling choice.
- 2026-09-27: plan committed while the second audit of the revised criteria (full mode, same [O] reader) still runs. Its findings land as a gated amendment before implement starts.

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

## Review
<!-- owner: review · exclusive -->
