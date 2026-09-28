<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M043: The OpenAI chat function refuses a messages value that holds a value that is not an atomic vector, a list, or NULL

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP3, GP4   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — it adds a refusal to an exported function and changes its help and error text   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m043-openai-messages-non-vector-values   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

`lms_chat_openai()` refuses, before the server probe, a `messages` value
that holds a value that is not an atomic vector, a list, or `NULL`.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** A new value rule in `R/utils-args.R`, beside `has_function()`
(line 423). `rlm_check_messages()` (line 345) runs it after the function
rule and before the trial write. It walks both forms of `messages` at any
depth, as `has_function()` does. It refuses a value that is not a
function and for which `is.atomic()`, `is.list()`, and `is.null()` are all
`FALSE`. The predicate reads the storage type, so a class set by hand
cannot hide such a value. RR01 fact 2 (`cairn/reviews/archive/`) gives the
reason that this is not the class list M040 rejected. Every jsonlite
method is for a vector, a list, or a data frame. So jsonlite writes such a
value as printed text or `null`, or fails. The help at `messages`, NEWS,
the internal comments, and the tests change to match. The ROADMAP
candidate row on such values closes with this milestone.

**Out:**
- A data-frame column that is a data frame with no columns counts as
  empty. It stays a candidate row (RR01 finding B1).
- An `NA` cell of a numeric matrix column is sent as `"NA"`, and a
  zero-extent matrix or array column counts as empty. Both stay
  candidate rows.
- A pairlist field and an S4 object that contains `"list"` are walked but
  not tested. No candidate row, because neither is a realistic field.
- A list-of-fields S3 class with no `as.list()` method (RR01 B2). RR01
  rejects work on it.
- A `POSIXlt` field passes every `messages` rule, but httr2 recurses
  without end when it builds the body. It is a candidate row for
  `/hotfix` (amended 2026-09-28).

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [x] AC1: In `lms_chat_openai()`, each kind below at each position below
  aborts before the server probe. The abort carries the value-fault
  header, "`messages` holds a field value that cannot be sent as JSON."
  Its detail is `You gave a field value of type "<type>", which is not an
  atomic vector, a list, or NULL.` Here `<type>` is the `typeof()` of the
  value. The call gives no R warning. Evidence is a test over every kind
  at every position, 105 cases. The fifteen kinds:
  - an environment, a symbol, a call, a formula, an expression vector,
    and an external pointer
  - an object of an S4 class that `methods::setClass()` defines with one
    numeric slot, and a reference-class object
  - an S4 class definition with a slot, and `methods::getClass("numeric")`
  - an environment with class `"POSIXt"`, and an environment with class
    `"classRepresentation"`
  - a call with class `"function"`, an expression vector with class
    `"json"`, and an external pointer with class `"NULL"`

  The seven positions:
  - a field of a list message, and an element of a list below a field
  - a column of a data-frame `messages` whose other cell is `NA`
  - a column of a data-frame column, and a cell of a list column
  - a cell of a list-matrix column, and a column of a data-frame field of
    a list message
- [x] AC2: In `lms_chat_openai()`, each value below passes every
  `messages` rule and reaches the request. The recorded body equals the
  sent form that the test states for it. The values:
  - a `NULL` field, and a `NULL` cell of a list column
  - a factor field, a `Date` field, and a `POSIXct` column
  - a field wrapped in `I()`, and an atomic matrix field
  - a list-matrix column, and a data-frame column
  - a field that is an object of an S4 class that contains `"numeric"`
- [x] AC3: In `lms_chat_openai()`, the new rule runs after the shape rules
  and the function rule and before the trial write. Tests show four cases.
  - A message that holds a function field and an environment field, in
    either field order, aborts with the function detail.
  - A message with an environment field and a field
    `structure("x", class = "foo")` aborts with the new detail.
  - A data frame whose one row is `NA` apart from an environment column
    aborts with the new detail, not the empty-row detail.
  - Each probe in `messages_probes` that holds an environment field and
    breaks a shape rule aborts with the shape header and the detail of
    that shape rule.
- [x] AC4: The `messages` help of `lms_chat_openai()` lists the new rule
  between the function rule and the jsonlite-write rule. It says that a
  `NULL` value passes. Its closing paragraph names the new kind among the
  field values that the package refuses. NEWS.md has an entry for the new
  refusal in the list form and the data-frame form. NEWS.md line 4 is the
  development sub-bullet on a column that is not a vector. It no longer
  gives the jsonlite-write error for the fifteen AC1 kinds. It no longer
  says that an S4 class definition with a slot is sent. The M040 NEWS
  example "or an environment" goes too. `man/lms_chat_openai.Rd` matches
  the roxygen after `devtools::document()`.
- [x] AC5: `devtools::test()` passes, and `devtools::check()` gives 0
  errors, 0 warnings, and 0 notes.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T2, T3
- AC4 → T4
- AC5 → T3, T5

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits) -->

- [x] T1: Write the tests first in `tests/testthat/test-arg-guards.R`. Add
  the new detail as `rule13` in `messages_rule_details` (line 847) and to
  `messages_value_rules`. Add the AC1 grid, the AC2 pass list, and the
  AC3 order cases. Build frame positions with `structure()`, because
  `$<-` refuses an environment in a frame with rows. Run them and see
  the AC1 and AC3 cases red.
- [x] T2: Add the walk beside `has_function()` in `R/utils-args.R`. It
  reads elements with a `for` loop, as the other walks do. Call it in
  `rlm_check_messages()` after the function rule. Splice the type into the
  detail as a value, so cli reads no braces from it. Update the comments
  that name only two value rules: `rlm_check_messages()` (line 336),
  `empty_rows()` (line 715), and `nested_names_fault()` (line 607).
- [x] T3: Rewrite the M042 test "a column that is not a vector is not
  empty and gives no warning" (line 1468) to expect `rule13`. Delete the
  test "an S4 class-definition column is sent only when it has a slot"
  (line 1614), because AC1 covers both class definitions. Keep the
  `empty_rows()` test and the test "each rule-order probe also fails the
  jsonlite write".
- [x] T4: Update the `messages` help in `R/chat.R` (lines 322 to 345) and
  NEWS.md as AC4 states. Run `devtools::document()`.
- [x] T5: Run `devtools::test()` and `devtools::check()`. Before the
  check, run `lms server start` and set `RLMSTUDIO_API_TOKEN` (LESSONS,
  M009).

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-09-28: created by /milestone-plan.
- 2026-09-28: The criteria audit ran in full mode with a fresh [O] reader. It returned 9 findings, and the gate fixed 6. The S4 object that contains `"numeric"` moved to the pass list, because jsonlite writes it as `1` (RR01 fact 7 did not hold). Two positions were added. The criteria now state package behavior. The order case pairs a function with an environment. The goal says "atomic vector". The stale comments and two M042 tests became T2 and T3. The other 3 findings were notes with no fault.
- 2026-09-28: The plan gate chose a type test over a class allow-list. Every jsonlite method is for a vector, a list, or a data frame (RR01 fact 2). Falsified by a jsonlite release that writes a non-vector type as its value.
- 2026-09-28: The plan gate chose one rule over both forms at any depth over a rule for data-frame columns alone. The list form sends the same bad text (RR01 fact 5). Falsified by a value that one form refuses and the other form sends.
- 2026-09-28: The plan gate chose a detail that names `typeof()` over fixed text, because it tells the user which value is wrong. Falsified by a user report that the type name misleads, such as "S4" for a reference-class object.
- 2026-09-28: The plan gate kept the function rule and its detail ahead of the new rule over one merged rule. The function detail says that jsonlite sends source text. Falsified by a user who reads the two details as one fault.
- 2026-09-28: The same [O] reader re-audited the changed criteria in full mode and returned no findings. Its probes built the 30 new-position cases and the 11 AC2 pass values with no error or warning.
- 2026-09-28: set in-progress on branch m043-openai-messages-non-vector-values. No implementation choice was open, so the question gate was skipped.
- 2026-09-28: T1 found that `httr2::req_dry_run()` on a body with a `POSIXlt` field fails with "evaluation nested too deeply: infinite recursion", on main too. The mini gate chose to drop that value from AC2, so AC2 now lists 10 pass values. The crash became a candidate row for `/hotfix`. The rejected option was a fix inside M043, which widens the milestone.
- 2026-09-28: re-audit: AC2 (full) — two findings. The gate accepted the Out bullet for the dropped `POSIXlt` field. It rejected a sent form derived from `jsonlite::toJSON()`, because such a form is derived from the artifact under test and cannot fail. The clause is unchanged by the amendment.
- 2026-09-28: T1 done. The AC1 grid, the AC2 pass list, and the AC3 order test are in `test-arg-guards.R`, and `rule13` is in the detail table. The two probes with an environment or `quote()` field now expect `rule13`. `sent_messages()` moved up the file so that the pass test can use it. On main code, the grid, order, and probe tests fail with the jsonlite-write detail (red for the right reason), and the pass test passes.
- 2026-09-28: T2 done. `non_vector_type()` in `R/utils-args.R` walks as `has_function()` does and returns the `typeof()` of the first value that is not atomic, a list, `NULL`, or a function. `rlm_check_messages()` calls it between the function rule and the trial write. The three stale comments name the new rule. `test-arg-guards.R` passes except the two M042 tests that T3 changes, which now get the new detail.
- 2026-09-28: T3 done. The M042 test on a column that is not a vector expects `rule13`. The test that sent an S4 class definition with a slot is deleted, because the AC1 grid covers both class definitions. `devtools::test()` gives 426 tests, 0 failed, 0 skipped.
- 2026-09-28: T4 done. The `messages` help in `R/chat.R` lists the new rule between the function rule and the trial write, says that a `NULL` field passes, and names the new kind in its closing paragraph. NEWS has a new entry. The M042 sub-bullet no longer names the jsonlite error for these kinds, and it no longer says that a slotted class definition is sent. The M040 example "or an environment" is gone. `devtools::document()` rewrote `man/lms_chat_openai.Rd` alone.
- 2026-09-28: T5 done. After `lms server start` with the token set, `devtools::check()` gave 0 errors, 0 warnings, and 0 notes at d3839fa.
- 2026-09-28: claim audit: 38 claims read, 3 corrected — NEWS.md, R/chat.R, R/utils-args.R, man/lms_chat_openai.Rd. The NEWS entry now says that a class definition with no slot was sent as `[]` as a field or list cell. It says that the jsonlite warning came only for a data-frame column. The help and the `non_vector_type()` comment add the object-or-array case. The same reader re-read the three and found them correct. After the fixes, `devtools::test()` gave 426 tests, 0 failed, 0 skipped. The check ran before these comment and documentation fixes.
- 2026-09-28: status set to review.
- 2026-09-28: review gate: findings O1, O2, O5 fixed on the branch, eight rejected, all logged in the Review section.
- 2026-09-28: step-7 approval: m043-openai-messages-non-vector-values approved for merge

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

## Review
<!-- owner: review · exclusive -->

Evidence gathered 2026-09-28 at 57c267a, which contains origin/main (bb00074).

- AC1: The test "a value that is not a vector, a list, or NULL aborts with its own detail" passes. It builds the fifteen kinds at the seven positions and asserts 105 cases. Each case gets the rule13 detail with the `typeof()` type and opens with the value header. No case gives the jsonlite-write detail or a warning. The server probe runs zero times.
- AC2: The test "values the non-vector rule passes reach the request" passes. It sends the ten listed values through a request recorder. For each, the parsed body equals the sent form that the test states by hand.
- AC3: The test "the non-vector rule sits between the function rule and the trial write" passes. A function field and an environment field give the function detail in both orders. An environment field beside a `"foo"` field gives the rule13 detail and not the jsonlite detail. A row that is `NA` apart from an environment column gives rule13 and not the empty-row detail. The probe test "a messages value that breaks a rule aborts before the server probe" passes. Its three probes with an environment field and a shape fault (rule7, rule8, rule9) open with the shape header and give their own detail.
- AC4: The `messages` help in `R/chat.R` lists the new rule between the function rule and the jsonlite-write rule. It says that a `NULL` field passes, and its closing paragraph names the new kind. NEWS.md has a new entry that covers the list form and the data-frame form. The M042 sub-bullet now gives the new error, not the jsonlite-write error, and no longer says that a class definition with a slot is sent. The M040 example "or an environment" is gone (grep finds no match). `devtools::document()` left the tree clean.
- AC5: `devtools::test()` gave 426 tests, 0 failed, 0 skipped, 0 warnings. After `lms server start` with the token set, `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- Gate: `cairn_validate.py` passed (exit 0). No DESIGN principle changed, so the impact report was skipped. `devtools::document()` gave no diff. README.Rmd and README.md are unchanged. The repo has no pkgdown site and the branch adds no top-level file. NEWS.md has the entry. The check is clean.

Independent review: three fresh reviewers, [O] diff, [S] history, [S] prior review. No finding shows a criterion failing. Proposed dispositions go to the gate.

- O1: A vector with a class set by hand, such as `structure(1L, class = "NULL")`, passes every rule and is sent as junk. NEWS says "a class attribute set by hand does not change the result", and the help says the same. A reader can think that such values are refused. A run shows the fault. Proposed: fix now, narrow the NEWS and help wording to values that are not vectors.
- O2: The help says "an S4 object breaks this rule". An S4 object that contains `"list"` passes and is walked. An S4 object that contains `"numeric"` is sent without its other slots. A run shows both. Proposed: fix now, narrow the help sentence.
- O3: Neither the help nor NEWS says that a `POSIXlt` field fails inside httr2. Proposed: reject, because the `/hotfix` candidate row covers it.
- O4: A reference-class object is named as type "S4". Proposed: reject, because the plan gate chose `typeof()` and recorded this risk.
- O5: The AC1 grid takes its expected type from `typeof(value)`, the same way the code does. Proposed: fix now, state the type of each kind by hand.
- O6: Raw, complex, pairlist, an S4 object that contains `"list"`, and an environment as an attribute pass untested. Proposed: reject, because the outcomes are reasonable and outside the criteria.
- O7: The `is.function()` test in `non_vector_type()` cannot be reached. Proposed: reject, because it keeps the walk safe on its own.
- O8: cli wraps the detail line in a narrow console. Proposed: reject, because every older rule does the same.
- S1: The deleted M042 test was the only test that a jsonlite warning in the trial write passes through. Proposed: reject, because no contract promises that behavior.
- S2: The deleted M042 test was one that RR01 said to keep. Proposed: reject, because RR01 option b-prime retires it and T3 records the reason.
- S3: The NEWS edits to earlier development bullets state present behavior correctly. Noted, no action.
- P: The prior-review lens found no finding that the diff reopens.
- Gate 2026-09-28: the user accepted the proposed dispositions. O1, O2, and O5 were fixed on the branch, and the other eight were rejected with the reasons above. The help and NEWS now say that a classed vector or list passes and is written by its class. The help says what happens to an S4 object that contains `"numeric"` or `"list"`. The grid test states each type by hand. A planted `class(value)[1]` in `non_vector_type()` turned that test red. After the fixes, `devtools::test()` gave 426 tests, 0 failed, and `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
