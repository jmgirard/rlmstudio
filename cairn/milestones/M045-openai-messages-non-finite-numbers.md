<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M045: The OpenAI chat function refuses a number that jsonlite writes as a string or drops

- **Status:** planned   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** M044   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP3, GP4   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — it adds a refusal to an exported function and changes its help   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** —   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

`lms_chat_openai()` refuses, before the server probe, a number in
`messages` that jsonlite writes as a string or leaves out with no
missing-field reason.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** A new value rule in `R/utils-args.R`. `rlm_check_messages()`
(line 346) runs it after `non_vector_type()` and before the trial write.
It walks both forms of `messages` at any depth, as `non_vector_type()`
does. It reads a double or integer vector whose class attribute is absent
or is `"AsIs"`. jsonlite writes an `NA`, `NaN`, `Inf`, or `-Inf` in such a
vector as the string `"NA"`, `"NaN"`, `"Inf"`, or `"-Inf"`. There is one
exception. In an atomic column with no `dim` attribute, of a data frame at
any depth, jsonlite leaves the cell out. There the rule refuses `Inf` and
`-Inf` alone. An `NA` or `NaN` cell there stays a missing field, because
`is.na()` is `TRUE` for both and the empty-row rule reads it so. The help,
the roxygen, NEWS, and tests change to match. The ROADMAP candidate row on
the numeric matrix `NA` closes with this milestone.

**Out:**
- A complex number. jsonlite writes every complex value as a string, so
  an `NA` is not a special case there. The server judges it. No
  candidate row.
- A number with a class other than `"AsIs"`, such as `as.Date(Inf)`,
  which jsonlite writes as `"Inf"`. It is written by its class, as
  today. The plan gate chose this bound. No candidate row.
- Array rows with no cells are M044.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [ ] AC1: `lms_chat_openai()` aborts before the server probe for each
      value below. The header is "`messages` holds a field value that
      cannot be sent as JSON.", and the detail names `NA`, `NaN`, and
      infinite numbers. The test "a number jsonlite cannot send as a number
      aborts" builds the values:
      - a double `NA`, `NaN`, `Inf`, and `-Inf`, and an integer `NA`, each
        in eight positions: a list-form field, one element of a longer
        list-form field vector, a field of a list nested in a field, a
        list-column cell, a list-matrix column cell, a matrix column, a
        three-dimensional array column, and a matrix column of a
        data-frame column
      - a double `NA` wrapped in `I()` as a list-form field
      - `Inf` and `-Inf` in an atomic data-frame column with no `dim`
        attribute, in four places: at the top level, inside a data-frame
        column, in a data frame given as a list-form field, and in a data
        frame in a list-column cell
- [ ] AC2: `lms_chat_openai()` still sends the values below. The test
      "numbers jsonlite leaves out, and classed values, still reach the
      request" builds them in two groups.
      - A double `NA` or `NaN` and an integer `NA` in an atomic data-frame
        column with no `dim` attribute, in the four places of AC1. The
        recorded body leaves that field out of the row.
      - A `Date` `NA`, a `POSIXct` `NA`, a `factor` `NA`, a character `NA`,
        and a logical `NA` as list-form fields, each sent as `null`. Also
        `as.Date(Inf)` as a list-form field, sent as `"Inf"`.
- [ ] AC3: The rule runs after the rule for a value that is not an atomic
      vector, a list, or `NULL`. It runs before the trial write. The test
      "the number rule sits between the non-vector rule and the trial
      write" builds two probes. An environment field beside a double `NA`
      field gets the non-vector detail. A field with class `"foo"` beside a
      double `NA` field gets the number detail.
- [ ] AC4: The help at `messages` in `R/chat.R`, `man/lms_chat_openai.Rd`,
      and the roxygen of `rlm_check_messages()`, `empty_rows()`, and
      `data_frame_messages_fault()` state the rule and the data-frame
      column case it leaves out. NEWS.md has one entry for the new refusal.
      After the change, `grep -n '"NA"' R/utils-args.R R/chat.R NEWS.md`
      finds no line that says a numeric `NA` is sent as `"NA"`. No
      milestone numbers appear.
- [ ] AC5: `devtools::document()` leaves the tree clean, and
      `devtools::test()` passes. `devtools::check()` gives 0 errors and 0
      warnings, and each note has a reason.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T3
- AC5 → T4

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. -->

- [ ] T1: Write the AC1, AC2, and AC3 tests in
      `tests/testthat/test-arg-guards.R`, beside the non-vector tests
      (line 1587). Match the detail text, not the header alone (LESSONS,
      M026). Confirm that the AC1 and AC3 tests are red on main. Rewrite
      the test "an NA in a three-dimensional atomic column is sent as
      jsonlite writes it" (line 2415), whose numeric case now aborts.
- [ ] T2: Add the rule and its walk to `R/utils-args.R` and call it from
      `rlm_check_messages()`. Plant two defects in a scratch copy and see
      a test go red for each: no data-frame exception, and no `AsIs`
      case.
- [ ] T3: Update the help and roxygen that AC4 names, and NEWS.md. Run
      the AC4 grep. Run `devtools::document()`.
- [ ] T4: Run `devtools::test()` and `devtools::check()`. The check needs
      `RLMSTUDIO_API_TOKEN` and a started server (LESSONS, M009).

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-09-28: created by /milestone-plan. Absorbs the candidate row on a numeric matrix `NA` sent as `"NA"` (M042 findings O3 and P3). Probes on 2026-09-28 showed the same string write in the list form, in list cells, and for `NaN` and `Inf`, so the scope covers them.
- 2026-09-28: criteria audit (full mode, fresh [O] reader) returned seven findings. AC1 gained data frames as a field and in a list cell, list-matrix cells, and nested matrix columns. AC2 gained `POSIXct` `NA` and `as.Date(Inf)`. AC4 names its stale-text sweep as a grep. Complex numbers moved to Out, because jsonlite writes every complex value as a string.
- 2026-09-28: plan gate chose to refuse `Inf` in a plain data-frame column over leaving it out like `NA`, because jsonlite drops it with no message; falsified by a user who relies on an `Inf` cell being left out of the message.
- 2026-09-28: plan gate chose a rule over unclassed and `I()` numbers over a rule that refuses `Inf` of any class, because a class test and a type test in one rule make the promise inexact; falsified by a classed number other than `AsIs` that a user sends and that jsonlite writes as `"Inf"` or `"NA"`.
- 2026-09-28: plan gate chose to refuse such numbers over sending `null` in their place, because `na = "null"` also turns every left-out `NA` cell of a data frame into a `null` field; falsified by a jsonlite option that writes a non-finite number as `null` and leaves data-frame cells alone.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

## Review
<!-- owner: review · exclusive. -->
