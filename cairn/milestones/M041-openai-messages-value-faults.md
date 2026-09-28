<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M041: The OpenAI chat function refuses a function or a list array inside a message, with a header for value faults

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP4   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — it changes which `messages` values an exported function accepts and the text of its abort   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m041-openai-messages-value-faults   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

`lms_chat_openai()` refuses, before the server probe, a function or a list
array inside a message, and it reports a value fault under its own header.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** Two new rules in `R/utils-args.R`. A function inside `messages`
aborts, because jsonlite writes it as its source text. A list with a `dim`
attribute inside a message aborts, because jsonlite writes it as nested
arrays with each cell boxed. The function rule and the trial-write rule of
M040 get a header of their own. Help at `messages`, NEWS, and tests say so.
The two ROADMAP candidate rows from the M040 scope and M040 review finding
O5 close with this milestone.

**Out:** Other values that jsonlite writes with no error. Examples are a
raw vector, a complex number, a factor, and a date. jsonlite writes each as
a string that holds the data value, so they get no rule and no row. An atomic
matrix field, which the help already calls an array. The other chat
functions take no `messages` argument.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [ ] AC1: `lms_chat_openai()` aborts before the server probe when
  `messages` holds a function at any place that a recursive walk of its
  lists and data frames reaches. The walk reaches four kinds of place. They
  are a field of a message and an element of a list at any depth below a
  field. They are also a column of a data frame, at the top or nested in a
  column, and a cell of a list column or a list-matrix column. The detail says that a field value is a
  function, which jsonlite sends as its source text, unless a rule that AC3
  orders earlier fires. The call gives no R
  warning on the way to the abort. A message with no function is sent.
- [ ] AC2: `lms_chat_openai()` aborts before the server probe when a list
  with a `dim` attribute sits inside a message. Inside a message means a
  field, an element of a list at any depth below a field, or a cell of a
  list column. A column of a data frame that is a list with one, three, or
  more dimensions also aborts. The detail says that a list inside a message
  has a `dim` attribute. A data frame is not such a list, but the rule reads
  the list-column cells of any data frame it reaches. Two kinds of value are
  still sent. One is an atomic matrix field. The other is a list-matrix
  column of any data frame, wherever that data frame sits.
- [ ] AC3: Each abort names one rule. All shape rules of M038 to M040 run
  first. Then come the AC2 rule, the name rule, the AC1 function rule, and
  the trial write. So a list array with repeated dimnames gets the AC2
  detail. A list-matrix inside a message that holds a function also gets
  the AC2 detail. The AC1 rule and the trial-write rule abort with
  no hint. Their header is "`messages` holds a field value that cannot be
  sent as JSON." Every other rule keeps its named-list hint. Its header
  stays "`messages` must be a data frame or an unnamed list of messages."
- [ ] AC4: The help at `messages` in `R/chat.R` and
  `man/lms_chat_openai.Rd` states the AC1 rule, the AC2 rule, and the two
  headers. It no longer says that a list with a `dim` inside a message is
  not checked. Its sentence on field values says that the package refuses a
  function and a value that jsonlite cannot write, and checks no other field
  value. NEWS.md has one entry for the two rules and the new header, with no
  milestone numbers.
- [ ] AC5: `devtools::document()` leaves the tree clean, apart from the
  known `@aliases` warning at `R/conditions.R:257`. `devtools::test()`
  passes. `devtools::check()` with the API token gives 0 errors and 0
  warnings, and any note is justified.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T2, T4
- AC2 → T1, T4
- AC3 → T1, T2, T3, T4
- AC4 → T5
- AC5 → T6

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits) -->

- [x] T1: Add the AC2 rule in `R/utils-args.R`. It walks from each message
  down. It exempts a data frame and its list-matrix columns, reads its
  list-column cells, and refuses its other list-array columns. It runs after the message `dim` rule and before
  `nested_names_fault()` in `messages_fault()` and
  `data_frame_messages_fault()`. One detail text. Delete the rule in a
  scratch copy and see its probes go red.
- [x] T2: Add the AC1 rule after the name rule and before
  `messages_write_fault()`. It walks the same places as `has_bad_name()`,
  data-frame columns included. Make `empty_rows()` read a function column
  with no `is.na()` warning. One detail text that names the source-text
  write.
- [x] T3: Split the header in `rlm_check_messages()`: the function and
  trial-write details take "`messages` holds a field value that cannot be
  sent as JSON." with no hint. Update the roxygen of `rlm_check_messages()`
  and `messages_write_fault()` so they no longer say the write rule is last
  or that no field value is judged.
- [x] T4: Tests in `tests/testthat/test-arg-guards.R`. Add the two details
  to `messages_rule_details` and a header per rule. The probe loop asserts
  the rule's header and the absence of the other header. AC1 probes are a
  closure field, a primitive field, and a function in a list in a field.
  More AC1 probes put a function in a list-column cell, in a list-matrix
  column cell, as a data-frame column, and in a nested data frame. One more
  is a function with class `"foo"`. AC2 probes are a list-matrix field and
  a one-dimensional and a three-dimensional list array field. More AC2
  probes are one with repeated dimnames, one in a list field, and one in a
  list-column cell. Two more are a data-frame column that is a
  one-dimensional and a three-dimensional list array. Order probes: a function with a bad
  name, and a list-matrix that holds a function. Sent controls through
  `sent_messages()`: a message with no function, an atomic matrix field, and
  a list-matrix column at both depths, and a data frame as a message field
  with a list-matrix column. Assert no warning on the data-frame
  function column.
- [ ] T5: Help at `messages` in `R/chat.R` per AC4, then
  `devtools::document()`. One NEWS.md entry.
- [ ] T6: Run `devtools::test()` and `devtools::check()` with the API token
  (see the LESSONS line on the vignettes and the server).

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-09-27: created by /milestone-plan.
- 2026-09-27: criteria audit (full mode, fresh [O] reader) returned 13 findings. Nine were fixed at the gate: places named directly, a function as a data-frame column, the `is.na()` warning, the rule order, a data frame exempt from the `dim` rule, list-matrix columns at any depth, wider probes, probes moved out of the criteria, and the field-value help sentence. Three became gate questions. Two had no finding.
- 2026-09-27: plan gate chose a separate header with no hint for the function and trial-write rules over one neutral header for all rules, because the shape hint is right for shape faults; falsified by a user who misreads a value fault as a shape fault under the new header.
- 2026-09-27: plan gate chose to refuse a list array inside a message over sending it as boxed nested arrays, to match the M040 rule for a list array as a whole message; falsified by a server or model that reads the boxed form as intended.
- 2026-09-27: plan gate chose to frame the function rule as a write rule with no D-entry over a new D-entry annotating D-003, because D-020 already limits D-003 to fields in `...`; falsified by a later rule that judges a field value jsonlite writes faithfully.
- 2026-09-27: plan committed while the second audit of the changed criteria (full mode, same [O] reader) still runs. Its findings land as a gated amendment before implement starts.
- 2026-09-27: second audit returned 4 findings, and all earlier findings but one were resolved. Three clear fixes applied: list-matrix columns of any data frame stay allowed, AC1 yields to earlier rules, and AC3 wording on the order. The gate chose to refuse a list-array column with one, three, or more dimensions over leaving it, because a three-dimensional column is sent boxed; falsified by a user who sends such a column on purpose. AC2, AC3, T1, and T4 amended.
- 2026-09-27: implement started on branch m041-openai-messages-value-faults. Question gate skipped, because the plan left no choice open.
- 2026-09-27: T1 done. `has_inner_list_array()` walks with `for` loops, because `as.list()` on a `POSIXlt` returns a `POSIXlt`. Nine rule11 probes added. With the rule returning FALSE in place, the probe loop went red. `devtools::test()` passed.
- 2026-09-27: T2 done. `has_function()` runs in `rlm_check_messages()` after `messages_fault()` and before the trial write. `empty_rows()` treats a function column as not empty. Eight rule12 probes, two order probes, and a no-warning test added. With the rule off, and apart from that with the `empty_rows()` change undone, the tests went red. `devtools::test()` passed.
- 2026-09-27: T3 done. `rlm_check_messages()` aborts shape faults with the old header and hint, then value faults with the new header and no hint. The probe loop now asserts the header, the other header's absence, and the hint per kind. With the old header on value faults, 26 checks went red. `devtools::test()` passed.
- 2026-09-27: T4 done. The probes and the no-warning test landed in T1 to T3. A new test sends five controls and compares the sent messages: a nested list with no function, an atomic matrix field, and a list-matrix column at the top, nested, and in a data-frame field. A planted refusal of list-matrix columns turned it red. `devtools::test()` passed.

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

## Review
<!-- owner: review · exclusive -->
