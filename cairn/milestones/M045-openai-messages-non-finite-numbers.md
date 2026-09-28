<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M045: The OpenAI chat function refuses a number that jsonlite writes as a string or drops

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** M044   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP3, GP4   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — it adds a refusal to an exported function and changes its help   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m045-openai-messages-non-finite-numbers   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

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
- Array rows with no cells are M046 (corrected in the M044 re-cut).

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [x] AC1: `lms_chat_openai()` aborts before the server probe for each
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
- [x] AC2: `lms_chat_openai()` still sends the values below. The test
      "numbers jsonlite leaves out, and classed values, still reach the
      request" builds them in two groups.
      - A double `NA` or `NaN` and an integer `NA` in an atomic data-frame
        column with no `dim` attribute, in the four places of AC1. The
        recorded body leaves that field out of the row.
      - A `Date` `NA`, a `POSIXct` `NA`, a `factor` `NA`, a character `NA`,
        and a logical `NA` as list-form fields, each sent as `null`. Also
        `as.Date(Inf)` as a list-form field, sent as `"Inf"`.
- [x] AC3: The rule runs after the rule for a value that is not an atomic
      vector, a list, or `NULL`. It runs before the trial write. The test
      "the number rule sits between the non-vector rule and the trial
      write" builds two probes. An environment field beside a double `NA`
      field gets the non-vector detail. A field with class `"foo"` beside a
      double `NA` field gets the number detail.
- [x] AC4: The help at `messages` in `R/chat.R`, `man/lms_chat_openai.Rd`,
      and the roxygen of `rlm_check_messages()`, `empty_rows()`, and
      `data_frame_messages_fault()` state the rule and the data-frame
      column case it leaves out. NEWS.md has one entry for the new refusal.
      After the change, `grep -n '"NA"' R/utils-args.R R/chat.R NEWS.md`
      finds no line that says a numeric `NA` is sent as `"NA"`. No
      milestone numbers appear.
- [x] AC5: `devtools::document()` leaves the tree clean, and
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

- [x] T1: Write the AC1, AC2, and AC3 tests in
      `tests/testthat/test-arg-guards.R`, beside the non-vector tests
      (line 1587). Match the detail text, not the header alone (LESSONS,
      M026). Confirm that the AC1 and AC3 tests are red on main. Rewrite
      the test "an NA in a three-dimensional atomic column is sent as
      jsonlite writes it" (line 2415), whose numeric case now aborts.
- [x] T2: Add the rule and its walk to `R/utils-args.R` and call it from
      `rlm_check_messages()`. Plant two defects in a scratch copy and see
      a test go red for each: no data-frame exception, and no `AsIs`
      case.
- [x] T3: Update the help and roxygen that AC4 names, and NEWS.md. Run
      the AC4 grep. Run `devtools::document()`.
- [x] T4: Run `devtools::test()` and `devtools::check()`. The check needs
      `RLMSTUDIO_API_TOKEN` and a started server (LESSONS, M009).

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-09-28: created by /milestone-plan. Absorbs the candidate row on a numeric matrix `NA` sent as `"NA"` (M042 findings O3 and P3). Probes on 2026-09-28 showed the same string write in the list form, in list cells, and for `NaN` and `Inf`, so the scope covers them.
- 2026-09-28: re-probed through `httr2::req_dry_run()` after M044 stopped on a bare-jsonlite premise. The list form still sends `[1,"NA","NaN","Inf"]`, a matrix column still sends `["NA","Inf"]`, and an atomic column still drops `Inf`. M044 is being re-cut, so this milestone's dependency on it needs a check at the re-plan.
- 2026-09-28: criteria audit (full mode, fresh [O] reader) returned seven findings. AC1 gained data frames as a field and in a list cell, list-matrix cells, and nested matrix columns. AC2 gained `POSIXct` `NA` and `as.Date(Inf)`. AC4 names its stale-text sweep as a grep. Complex numbers moved to Out, because jsonlite writes every complex value as a string.
- 2026-09-28: plan gate chose to refuse `Inf` in a plain data-frame column over leaving it out like `NA`, because jsonlite drops it with no message; falsified by a user who relies on an `Inf` cell being left out of the message.
- 2026-09-28: plan gate chose a rule over unclassed and `I()` numbers over a rule that refuses `Inf` of any class, because a class test and a type test in one rule make the promise inexact; falsified by a classed number other than `AsIs` that a user sends and that jsonlite writes as `"Inf"` or `"NA"`.
- 2026-09-28: plan gate chose to refuse such numbers over sending `null` in their place, because `na = "null"` also turns every left-out `NA` cell of a data frame into a `null` field; falsified by a jsonlite option that writes a non-finite number as `null` and leaves data-frame cells alone.
- 2026-09-28: the M044 re-cut kept the dependency on M044. M044 now makes the request send what jsonlite writes, and the numbers this milestone refuses are written the same way before and after. The dependency stays because both edit `rlm_check_messages()` and its help. The Out pointer to array rows moved to M046.
- 2026-09-28: implement started on branch `m045-openai-messages-non-finite-numbers`. No question gate, because the plan left nothing open.
- 2026-09-28: T1 done. The AC1 and AC3 tests were red on main, and the AC2 test was green. The 3-D array test now covers character and logical columns alone.
- 2026-09-28: minor amendment to T1. Three more fixtures sent a numeric array `NA` and now abort. They test the empty-row rule, so they now use character values.
- 2026-09-28: T2 done. `has_unsendable_number()` runs between the non-vector rule and the trial write. Each planted defect turned a test red.
- 2026-09-28: the AC2 test gained a named-zone `POSIXlt` field. Its `gmtoff` part is an integer `NA`, and a first walk refused it.
- 2026-09-28: T3 done. The help, the roxygen, and NEWS state the rule. The AC4 grep finds three lines, and each states what jsonlite writes or wrote before. `document()` rewrote `man/lms_chat_openai.Rd`.
- 2026-09-28: T4 done. `devtools::test()` passed. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes, with the token set, before and after the claim-audit fixes.
- 2026-09-28: claim audit: 51 claims read, 4 corrected — NEWS.md, R/chat.R, man/lms_chat_openai.Rd, R/utils-args.R, tests/testthat/test-arg-guards.R
- 2026-09-28: the claim-audit re-read found one gap left in the closing help summary, which now names the class limit. There was no second pass.
- 2026-09-28: status set to review.
- 2026-09-28: review returned M045 to in-progress (defect return 1). AC4 failed, because the roxygen of `data_frame_messages_fault()` and `rlm_check_messages()` does not state the plain data-frame column case. AC1 to AC3 passed.
- 2026-09-28: AC4 fix. The roxygen of `rlm_check_messages()` and `data_frame_messages_fault()` now states the number rule and the plain data-frame column case. The AC4 grep finds the same 3 lines.
- 2026-09-28: claim audit: 11 claims read, 2 corrected — R/utils-args.R
- 2026-09-28: the claim audit found a code gap. A list classed `c("foo", "list")` holding a double `NA` passed and was sent as `"NA"`. The walk now enters a classed list when `written_as_list()` finds that jsonlite writes it as the bare list. A new test covers two such cases, and the help at `messages` and three roxygen blocks changed to match. Planting `written_as_list()` as always `FALSE` turned the new test red, and as always `TRUE` turned the `POSIXlt` case red.
- 2026-09-28: the claim-audit re-read found 9 claims, 1 still wrong, now corrected in the `data_frame_messages_fault()` roxygen. There was no second pass. It also found a list classed `"json"` holding `NA_real_` sent as `"NA"`, which became a candidate row.
- 2026-09-28: `devtools::test()` passed, and `devtools::check()` gave 0 errors, 0 warnings, and 0 notes, with the token set.
- 2026-09-28: status set to review.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

- 2026-09-28: The number walk starts from the value that `unclass_messages()` returns. Below the messages, it does not enter a list whose class is not `"AsIs"` or a data frame. jsonlite writes such a list by its class. A named-zone `POSIXlt` holds an integer `NA` in `gmtoff` and is sent as a date and time.
- 2026-09-28 (supersedes the entry above in part): Take a list whose class is not `"AsIs"` or a data frame. If jsonlite writes it as it writes the bare list, the number walk enters it. The earlier entry assumed that jsonlite writes every such list by its class. jsonlite writes a list classed `c("foo", "list")` as a plain list, so its numbers were sent as strings. The `POSIXlt` case stands, because jsonlite writes it differently from the bare list.

## Review
<!-- owner: review · exclusive. -->

- 2026-09-28 sync: `origin/main` has not moved since the branch was cut. No PR exists.
- AC1 evidence (2026-09-28): the test "a number jsonlite cannot send as a number aborts" passed with 100 expectations, 0 failed. It builds 49 cases. They are the 5 numbers in the 8 named positions, the `I()` double `NA`, and `Inf` and `-Inf` in the 4 places. It matches the detail text and the header, and the probe count is 0. Against main's `R/` code in a scratch copy, the test errors.
- AC2 evidence (2026-09-28): the test "numbers jsonlite leaves out, and classed values, still reach the request" passed with 39 expectations, 0 failed. The 12 plain-column cases send a body without `x`. The 5 classed and atomic `NA` fields are sent as `null`, and `as.Date(Inf)` is sent as `"Inf"`.
- AC3 evidence (2026-09-28): the test "the number rule sits between the non-vector rule and the trial write" passed with 6 expectations, 0 failed. Against main's `R/` code, it errors.
- AC4 FAILED (2026-09-28): the roxygen of `data_frame_messages_fault()` names the number rule but does not state the plain data-frame column case it leaves out. The roxygen of `rlm_check_messages()` points to `has_unsendable_number()` for that case and does not state it. The help in `R/chat.R`, the `.Rd` file, and `empty_rows()` do state both. The grep finds 3 lines, and each says what jsonlite writes or wrote before. NEWS has one entry and no milestone numbers.
- AC5: not run, because review stopped at AC4.
- Pass 2 sync (2026-09-28): `origin/main` is still at `12d03e8`, the branch base. No PR exists.
- AC1 evidence, pass 2 (2026-09-28): the test "a number jsonlite cannot send as a number aborts" passed with 100 expectations, 0 failed. Its 49-case count held after the walk change. Against main's `R/` code in a scratch copy, it errors.
- AC2 evidence, pass 2 (2026-09-28): the test "numbers jsonlite leaves out, and classed values, still reach the request" passed with 39 expectations, 0 failed. It is a pass control, and it also passes on main's `R/` code.
- AC3 evidence, pass 2 (2026-09-28): the test "the number rule sits between the non-vector rule and the trial write" passed with 6 expectations, 0 failed. Against main's `R/` code, it errors.
- AC4 evidence, pass 2 (2026-09-28): the help at `messages` in `R/chat.R` and `man/lms_chat_openai.Rd` state the rule and the plain data-frame column case. So do the roxygen blocks of `rlm_check_messages()`, `data_frame_messages_fault()`, and `empty_rows()`. NEWS has one entry for the refusal. The grep finds 3 lines. Each says what jsonlite writes or sent before. `grep -nE "M[0-9]{3}"` finds no milestone number in NEWS, the help, or the `.Rd` file.
- AC5 evidence, pass 2 (2026-09-28): `devtools::document()` left the tree clean. `devtools::test()` ran 12457 expectations with 0 failed and 0 errors. `devtools::check()` with the token set gave 0 errors, 0 warnings, and 0 notes.
- Consistency gate, pass 2 (2026-09-28): `cairn_validate` passed. No principle in `DESIGN.md` changed, so `cairn_impact` was skipped. `document()` gave no diff, and the branch hand-edits no generated file. The branch does not touch `README.Rmd`, and the repo has no pkgdown site. NEWS has the entry, and the branch adds no top-level file.
- Review lenses, pass 2 (2026-09-28): the prior-review lens found no findings. The gh probe found no PR review comments. The blame-history lens found no defect and one note (B1). The diff-bug lens found 8 findings (O1 to O8), and none breaks a criterion. The session re-ran O1 and O2 and saw the same results.
- O1: `written_as_list()` writes a classed list twice at every level, so a deep stack is slow. 100 nested `c("foo", "list")` levels took 2.1 s in the rule and 0.03 s in the write.
- O2: `jsonlite::unbox(NA_real_)` has the class `c("scalar", "numeric")`, passes, and is sent as `"NA"`. `unbox(Inf)` is sent as `"Inf"`. This is inside the plan gate's class bound.
- O3: other classed numbers pass and are sent as strings, such as `structure(NA_real_, class = "numeric")`, an S4 number, and `as.POSIXct(Inf)`. This is inside the class bound too.
- O4: a list classed `"scalar"` holding `NA_real_` passes and is sent as `"NA"`, like the `"json"` candidate row.
- O5: the NEWS entry says the rule reads "a list below a field" and does not state the classed-list limit that the help states.
- O6: the `has_unsendable_number()` roxygen says its walk is the walk of `non_vector_type()`, but it skips some classed lists.
- O7: no test covers an `I()` atomic data-frame column, a 1-D array column, or a `written_as_list()` write that fails. The code handles all three.
- O8: the classed-list writes add to the trial write, the cost behind O1.
- B1: the field loop in `has_unsendable_number()` relies on `messages_fault()` to make each message a named list.
