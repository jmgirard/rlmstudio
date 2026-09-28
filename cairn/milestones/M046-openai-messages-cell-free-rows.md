<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M046: The OpenAI chat function counts an array row with no cells as a field value

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** M044   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP4   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — it changes which `messages` values `lms_chat_openai()` sends   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m046-openai-messages-cell-free-rows   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

`lms_chat_openai()` does not count a `messages` column with a `dim`
attribute as empty in a row that holds no cells of it.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** `empty_rows()` in `R/utils-args.R:766` counts a column with a `dim`
attribute as not empty in a row that has no cells of it. After M044, the
request sends such a row as jsonlite writes it, as `[]` or as nested empty
arrays. This is the same rule M040 chose for a `list()` cell. The help and
NEWS state the change. A test pins the current rule for a data-frame
column with no columns, which still counts as empty. The help states that
rule too.

**Out:** A number that jsonlite writes as a string or drops is M045. A
data-frame column that always counts as a field value was declined at the
first M044 plan gate, and M040's recursion stays. RR01 finding B2 and the
`NULL` column stay rejected, as RR01 recommends.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [ ] AC1: `lms_chat_openai()` passes each frame below through every
      `messages` rule. The recorded request body holds the extra column in
      row 2 as jsonlite writes it. Each frame has the columns
      `role = c("user", NA)` and `content = c("Hi", NA)` plus one extra
      column. A test builds the six frames. The extra column is one of
      these:
      - a 2-by-0 numeric matrix, written `[]`
      - a 2-by-0 character matrix, written `[]`
      - a 2-by-0 list matrix, written `[]`
      - a 2-by-0-by-3 array, written `[]`
      - a 2-by-3-by-0 array, written `[[],[],[]]`
      - a data-frame column whose one column is a 2-by-0 numeric matrix,
        written `{"m":[]}`
- [ ] AC2: `lms_chat_openai()` still aborts before the server probe with the
      empty-row detail for three frames of the same form. This behavior is
      on main, and the criterion pins it. The extra column is one of these:
      - a data frame with no columns, whose cell in row 2 is written `{}`
      - a data frame with one numeric column that is `NA` in row 2, whose
        cell in row 2 is written `{}`
      - a data frame whose one column is a data frame with no columns,
        whose cell in row 2 is written `{"m":{}}`
- [ ] AC3: The help at `messages` in `R/chat.R` and
      `man/lms_chat_openai.Rd` states two rules. A column with a `dim`
      attribute and no cells in a row is not empty in that row. A
      data-frame column counts as empty in a row when each of its own
      columns is empty in that row. So a data frame with no columns counts
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

- [x] T1: Write the AC1 test "a column with no cells in a row is not
      empty" and the AC2 test "a data-frame column with only empty columns
      counts as empty" in `tests/testthat/test-arg-guards.R`, beside "a
      column that is not a vector is not empty and gives no warning". Use
      the request recorder for AC1 and the counted probe mock for AC2.
      Commit `a1fb74e` of the deleted first M044 branch holds a draft of
      both, if git still keeps it. Confirm that the AC1 test is red and the
      AC2 test is green before T2.
- [ ] T2: In `empty_rows()`, return `FALSE` for each row of a `dim` column
      whose extents after the first multiply to zero. Plant the old
      `apply()` path back in a scratch copy and see the AC1 test go red.
- [ ] T3: Update the `messages` help in `R/chat.R` (about line 288), the
      `empty_rows()` roxygen, and NEWS.md. Run `devtools::document()`.
- [ ] T4: Run `devtools::test()` and `devtools::check()`. The check needs
      `RLMSTUDIO_API_TOKEN` and a started server (LESSONS, M009).

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-09-28: created by /milestone-plan in the M044 re-cut. It carries the first M044 plan's rule, which rested on a write that httr2 changed. It now depends on M044, which makes the request send what jsonlite writes. The first M044 plan's gate choices (M040's recursion kept) and its audit stand in the M044 work log.
- 2026-09-28: criteria audit (full mode, fresh [O] reader) passed AC1 and AC4. AC2 now says that the cell in row 2, not the row, is written `{}`, and it gained a nested data frame with no columns, written `{"m":{}}`, which the recursion also counts as empty. Test names moved to T1.
- 2026-09-28: implement started on branch m046-openai-messages-cell-free-rows. The plan left no choice open, so no question gate ran.
- 2026-09-28: T1 done. The tests come from draft `a1fb74e`. They add the nested data frame with no columns and check that jsonlite writes each row-2 cell as AC2 states. The AC1 test is red with the empty-row detail. The AC2 test is green.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

## Review
<!-- owner: review · exclusive. -->
