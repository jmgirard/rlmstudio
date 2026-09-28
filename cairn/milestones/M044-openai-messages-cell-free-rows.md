<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M044: The OpenAI chat function counts an array row with no cells as a field value

- **Status:** planned   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP4   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — it changes which `messages` values `lms_chat_openai()` sends   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** —   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

`lms_chat_openai()` does not count a `messages` column with a `dim`
attribute as empty in a row that holds no cells of it.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** `empty_rows()` in `R/utils-args.R:766` counts a column with a `dim`
attribute as not empty in a row that has no cells of it. jsonlite writes
such a row as `[]` or as nested empty arrays. This is the same rule M040
chose for a `list()` cell. The help and NEWS state the change. A test pins
the current rule for a data-frame column with no columns, which still
counts as empty. The help states that rule too.

**Out:** A number that jsonlite writes as a string or drops is M045. A
data-frame column that always counts as a field value was declined at this
plan gate, and M040's recursion stays. RR01 findings B2 and the `NULL`
column stay rejected, as RR01 recommends.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [ ] AC1: `lms_chat_openai()` passes each frame below through every
      `messages` rule. The recorded request body holds the extra column in
      row 2 as jsonlite writes it. Each frame has the columns
      `role = c("user", NA)` and `content = c("Hi", NA)` plus one extra
      column. The test "a column with no cells in a row is not empty" builds
      the six frames. The extra column is one of these:
      - a 2-by-0 numeric matrix, written `[]`
      - a 2-by-0 character matrix, written `[]`
      - a 2-by-0 list matrix, written `[]`
      - a 2-by-0-by-3 array, written `[]`
      - a 2-by-3-by-0 array, written `[[],[],[]]`
      - a data-frame column whose one column is a 2-by-0 numeric matrix,
        written `{"m":[]}`
- [ ] AC2: `lms_chat_openai()` still aborts before the server probe with the
      empty-row detail for two frames of the same form. This behavior is on
      main, and the criterion pins it. The extra column is a data frame with
      no columns, or a data frame with one numeric column that is `NA` in
      row 2. jsonlite writes both as `{}` in row 2. The test "a data-frame
      column written as an empty object counts as empty" builds both.
- [ ] AC3: The help at `messages` in `R/chat.R` and
      `man/lms_chat_openai.Rd` states two rules. A column with a `dim`
      attribute and no cells in a row is not empty in that row. A
      data-frame column counts as empty in a row when each of its own
      columns is empty in that row, so a data frame with no columns counts
      as empty. The `empty_rows()` roxygen says the same. NEWS.md has one
      entry for the AC1 change, with no milestone number.
- [ ] AC4: `devtools::document()` leaves the tree clean, and
      `devtools::test()` passes. `devtools::check()` gives 0 errors and 0
      warnings, and each note has a reason.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T1, T2
- AC2 → T1
- AC3 → T3
- AC4 → T4

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. -->

- [ ] T1: Write the AC1 and AC2 tests in `tests/testthat/test-arg-guards.R`,
      beside "a column that is not a vector is not empty and gives no
      warning" (line 1784). Use the request recorder for AC1 and the counted
      probe mock for AC2. Confirm that the AC1 test is red on main and that
      the AC2 test is green.
- [ ] T2: In `empty_rows()`, return `FALSE` for each row of a `dim` column
      whose extents after the first multiply to zero. Plant the old
      `apply()` path back in a scratch copy and see the AC1 test go red.
- [ ] T3: Update the `messages` help in `R/chat.R` (about line 288), the
      `empty_rows()` roxygen, and NEWS.md. Run `devtools::document()`.
- [ ] T4: Run `devtools::test()` and `devtools::check()`. The check needs
      `RLMSTUDIO_API_TOKEN` and a started server (LESSONS, M009).

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-09-28: created by /milestone-plan. Absorbs two candidate rows: the zero-extent array column (M042 findings O4 and P2) and the zero-column data-frame column (RR01 finding B1).
- 2026-09-28: criteria audit (full mode, fresh [O] reader) returned four findings, all fixed. AC1 gained a nested zero-width matrix and a character matrix. AC1 and AC2 now state behavior and name the test as the procedure. The AC3 help sentence changed, because the `{}` wording was false for `{"l":null}`.
- 2026-09-28: plan gate chose to keep M040's recursion, so a data-frame column with no columns counts as empty, over counting every data-frame column as a field value, because both write the same `{}` as a nested row of `NA` cells that M040 refuses; falsified by a server that answers a message holding only `{}` fields as a normal message.
- 2026-09-28: /milestone-implement started on branch `m044-openai-messages-cell-free-rows` and stopped at T2, because the goal is wrong. The plan probed bare `jsonlite::toJSON()`. The request goes through httr2 1.3.0, whose `unobfuscate_rec()` rebuilds each list in the body with `x[] <- lapply(x, ...)`. On a data frame, that turns a zero-width matrix or array column into `NA` and a 2-by-0 list matrix into `NULL`. `httr2::req_dry_run()` shows row 2 of the AC1 frames sent as `{}` or `{"x":null}`, which is the empty message the empty-row rule refuses. So today's abort is right for five of the six AC1 frames. The nested frame is sent as `{"x":{}}`, which M040's rule counts as empty. Status back to planned for a re-cut.
- 2026-09-28: the branch holds the T1 tests (`a1fb74e`, cleaned in `e3b521b`), which assert the false premise. It is unpushed. The re-cut decides whether to delete it. Two leads for the re-cut: `messages_write_fault()` runs bare `jsonlite::toJSON()` and not httr2's walk, so the trial write can pass a body that httr2 sends in another form. The `POSIXlt` recursion in the candidate rows can have the same cause.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

## Review
<!-- owner: review · exclusive. -->
