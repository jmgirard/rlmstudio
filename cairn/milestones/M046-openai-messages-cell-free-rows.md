<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M046: The OpenAI chat function counts an array row with no cells as a field value

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
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

- [x] AC1: `lms_chat_openai()` passes each frame below through every
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
- [x] AC2: `lms_chat_openai()` still aborts before the server probe with the
      empty-row detail for three frames of the same form. This behavior is
      on main, and the criterion pins it. The extra column is one of these:
      - a data frame with no columns, whose cell in row 2 is written `{}`
      - a data frame with one numeric column that is `NA` in row 2, whose
        cell in row 2 is written `{}`
      - a data frame whose one column is a data frame with no columns,
        whose cell in row 2 is written `{"m":{}}`
- [x] AC3: The help at `messages` in `R/chat.R` and
      `man/lms_chat_openai.Rd` states two rules. A column with a `dim`
      attribute and no cells in a row is not empty in that row. A
      data-frame column counts as empty in a row when each of its own
      columns is empty in that row. So a data frame with no columns counts
      as empty. The `empty_rows()` roxygen says the same. NEWS.md has one
      entry for the AC1 change, with no milestone number.
- [x] AC4: `devtools::document()` leaves the tree clean, and
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
- [x] T2: In `empty_rows()`, return `FALSE` for each row of a `dim` column
      whose extents after the first multiply to zero. Plant the old
      `apply()` path back in a scratch copy and see the AC1 test go red.
- [x] T3: Update the `messages` help in `R/chat.R` (about line 288), the
      `empty_rows()` roxygen, and NEWS.md. Run `devtools::document()`.
- [x] T4: Run `devtools::test()` and `devtools::check()`. The check needs
      `RLMSTUDIO_API_TOKEN` and a started server (LESSONS, M009).

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-09-28: created by /milestone-plan in the M044 re-cut. It carries the first M044 plan's rule, which rested on a write that httr2 changed. It now depends on M044, which makes the request send what jsonlite writes. The first M044 plan's gate choices (M040's recursion kept) and its audit stand in the M044 work log.
- 2026-09-28: criteria audit (full mode, fresh [O] reader) passed AC1 and AC4. AC2 now says that the cell in row 2, not the row, is written `{}`, and it gained a nested data frame with no columns, written `{"m":{}}`, which the recursion also counts as empty. Test names moved to T1.
- 2026-09-28: implement started on branch m046-openai-messages-cell-free-rows. The plan left no choice open, so no question gate ran.
- 2026-09-28: T1 done. The tests come from draft `a1fb74e`. They add the nested data frame with no columns and check that jsonlite writes each row-2 cell as AC2 states. The AC1 test is red with the empty-row detail. The AC2 test is green.
- 2026-09-28: T2 done. `empty_rows()` returns `FALSE` for each row of a `dim` column whose extents after the first multiply to zero. With the old `empty_rows()` put back through `assignInNamespace()`, the AC1 test was red with the empty-row detail. With the fix, its 12 expectations passed, and `devtools::test()` passed with no failure or skip.
- 2026-09-28: T3 done. The `messages` help, the `empty_rows()` roxygen, and one NEWS entry state both rules. `devtools::document()` rewrote `man/lms_chat_openai.Rd` alone.
- 2026-09-28: T4 done. With the token set and the server started, `devtools::test()` passed, and `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. A second `devtools::document()` left the tree clean. The check left the server off, as LESSONS M009 says.
- 2026-09-28: claim audit: 16 claims read, 1 corrected — NEWS.md, R/chat.R, man/lms_chat_openai.Rd, R/utils-args.R, tests/testthat/test-arg-guards.R. The fresh [O] reader found every claim true. It flagged one AC2 test comment that called `{"m":{}}` an object with no field value. The comment now says `{}`, or an object whose only field holds `{}`, and the same reader's one re-read found it true.
- 2026-09-28: status set to review.
- step-7 approval: m046-openai-messages-cell-free-rows approved for merge, with the proposed triage: fix O1, O2, O3, and the list-array part of O6, file O5 with the classed matrix as one candidate row, and reject O4 and P1.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

## Review
<!-- owner: review · exclusive. -->

Main had not moved since the branch was cut (`3f4cf51`), and no PR existed.

- AC1 (2026-09-28): the test "a column with no cells in a row is not empty" ran 12 expectations with 0 failures. Its six cases are the six columns AC1 lists. Each case checks for no error and checks the recorded body against the row-2 text AC1 states. At T2, the old `empty_rows()` turned this test red with the empty-row detail.
- AC2 (2026-09-28): the test "a data-frame column with only empty columns counts as empty" ran 7 expectations with 0 failures. For each of the three columns AC2 lists, it checks that `rlm_json_text()` writes the row-2 cell as `{}`, `{}`, or `{"m":{}}`. It also checks the empty-row detail. The probe count stayed 0.
- AC3 (2026-09-28): `R/chat.R:290-297` and `man/lms_chat_openai.Rd:47-53` say that a `dim` column with no cells in a row is not empty in that row. They also give the data-frame rule. If each of its own columns is empty in a row, a data-frame column counts as empty there. So one with no columns counts as empty. The `empty_rows()` roxygen (`R/utils-args.R:873-885`) states both rules. The branch adds one NEWS.md entry, and no `M0NN` appears in the NEWS diff.
- AC4 (2026-09-28): `devtools::document()` left `git status` empty. With the token set and the server started, `devtools::test()` ran 437 tests and 12482 expectations with 0 failures, 0 skips, and 0 errors. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- Consistency gate (2026-09-28): `cairn_validate.py` passed with exit 0. No DESIGN.md principle changed, so `cairn_impact` was skipped. `document()` left no diff, and `man/` changed only through it. The branch leaves README.Rmd alone. `pkgdown::check_pkgdown()` found no problems. NEWS.md has the entry. The branch adds no top-level file. The full check is under AC4.

Independent review (2026-09-28), three fresh reviewers. Proposed dispositions go to the merge gate.

- O1 (diff-bug): the help at `R/chat.R:296-297` says "a data frame with no columns", which can be read as the `messages` frame itself. The roxygen and NEWS say "a data-frame column". Proposed: fix now.
- O2 (diff-bug): NEWS says a matrix or array column with no cells in a row "is now sent". A zero-width list array of 3 or more dimensions is still refused, now by the list-array rule. A classed zero-width matrix, such as class `"Date"`, now gets jsonlite's "values must be length 2" error in place of the empty-row detail. Both were checked by a run on this branch. Proposed: fix now, and narrow NEWS to an atomic matrix or array or a list matrix.
- O3 (diff-bug): the NEWS entry opens "Take a matrix ...", unlike its neighbors. Proposed: fix now.
- O4 (diff-bug): the empty-row rule's first help sentence holds only vacuously for a row with no cells. The next sentence settles it. Proposed: reject, because the new sentence already states the rule.
- O5 (diff-bug, not changed by the diff): a malformed frame whose `dim` column's first extent is not the row count makes `empty_rows()` return more than one value per row. A run on this branch returned a 3-by-2 matrix for a 2-row frame. Proposed: follow-up candidate row.
- O6 (diff-bug): no test pins the refusal of a zero-width list array of 3 or more dimensions or of a classed zero-width matrix. Proposed: fix now for the list array, which backs the narrowed NEWS. The classed matrix joins the O5 candidate row.
- O7 (diff-bug): jsonlite writes `array(numeric(0), c(2,3,0,2))` as `[[],[],[]]`, which "nested empty arrays" still describes. Proposed: noted.
- P1 (prior review): the AC2 test pins RR01 finding B1, the nested data frame with no columns, as an abort, and RR01 called that a false abort. Proposed: reject. The first M044 plan gate absorbed B1 and kept M040's recursion on purpose (`d5061db`, M044 work log). Scope Out and AC2 carry that choice.
- Blame-history: no findings.

Triage at the merge gate (2026-09-28), as proposed. O1, O2, and O3 were fixed now in the help and NEWS. O6 was fixed now for the list array with the test "a list array with no cells in a row gets the list-array detail", 5 expectations, 0 failures. O5 and the classed-matrix part of O6 became one candidate row in ROADMAP. O4 and P1 were rejected for the reasons above, and O7 was noted. After the fixes, `devtools::document()` rewrote `man/lms_chat_openai.Rd` alone, and `devtools::test()` ran 438 tests and 12487 expectations with 0 failures, 0 skips, and 0 errors. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes, and `cairn_validate.py` passed.
