<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M043: The OpenAI chat function refuses a messages value that holds a value that is not an atomic vector, a list, or NULL

- **Status:** planned   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP3, GP4   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — it adds a refusal to an exported function and changes its help and error text   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** —   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

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

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [ ] AC1: In `lms_chat_openai()`, each kind below at each position below
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
- [ ] AC2: In `lms_chat_openai()`, each value below passes every
  `messages` rule and reaches the request. The recorded body equals the
  sent form that the test states for it. The values:
  - a `NULL` field, and a `NULL` cell of a list column
  - a factor field, a `Date` field, a `POSIXct` column, and a `POSIXlt`
    field
  - a field wrapped in `I()`, and an atomic matrix field
  - a list-matrix column, and a data-frame column
  - a field that is an object of an S4 class that contains `"numeric"`
- [ ] AC3: In `lms_chat_openai()`, the new rule runs after the shape rules
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
- [ ] AC4: The `messages` help of `lms_chat_openai()` lists the new rule
  between the function rule and the jsonlite-write rule. It says that a
  `NULL` value passes. Its closing paragraph names the new kind among the
  field values that the package refuses. NEWS.md has an entry for the new
  refusal in the list form and the data-frame form. NEWS.md line 4 is the
  development sub-bullet on a column that is not a vector. It no longer
  gives the jsonlite-write error for the fifteen AC1 kinds. It no longer
  says that an S4 class definition with a slot is sent. The M040 NEWS
  example "or an environment" goes too. `man/lms_chat_openai.Rd` matches
  the roxygen after `devtools::document()`.
- [ ] AC5: `devtools::test()` passes, and `devtools::check()` gives 0
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

- [ ] T1: Write the tests first in `tests/testthat/test-arg-guards.R`. Add
  the new detail as `rule13` in `messages_rule_details` (line 847) and to
  `messages_value_rules`. Add the AC1 grid, the AC2 pass list, and the
  AC3 order cases. Build frame positions with `structure()`, because
  `$<-` refuses an environment in a frame with rows. Run them and see
  the AC1 and AC3 cases red.
- [ ] T2: Add the walk beside `has_function()` in `R/utils-args.R`. It
  reads elements with a `for` loop, as the other walks do. Call it in
  `rlm_check_messages()` after the function rule. Splice the type into the
  detail as a value, so cli reads no braces from it. Update the comments
  that name only two value rules: `rlm_check_messages()` (line 336),
  `empty_rows()` (line 715), and `nested_names_fault()` (line 607).
- [ ] T3: Rewrite the M042 test "a column that is not a vector is not
  empty and gives no warning" (line 1468) to expect `rule13`. Delete the
  test "an S4 class-definition column is sent only when it has a slot"
  (line 1614), because AC1 covers both class definitions. Keep the
  `empty_rows()` test and the test "each rule-order probe also fails the
  jsonlite write".
- [ ] T4: Update the `messages` help in `R/chat.R` (lines 322 to 345) and
  NEWS.md as AC4 states. Run `devtools::document()`.
- [ ] T5: Run `devtools::test()` and `devtools::check()`. Before the
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

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

## Review
<!-- owner: review · exclusive -->
