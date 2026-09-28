<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M044: The functions that send a JSON body send the text that jsonlite writes

- **Status:** planned   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP4   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — it changes the request body that seven exported functions send   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** —   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

Each function that sends a JSON request body sends the text that
`jsonlite::toJSON()` writes from the body, with the options of the
`messages` trial write. It does not send a copy that httr2 rebuilds first.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** httr2 1.3.0 `req_body_json()` runs `unobfuscate_rec()` over the
body before it writes it. That walk runs `x[] <- lapply(x, ...)` on each
list, a data frame included. On a data frame, it turns a zero-width matrix
or array column into `NA` and a 2-by-0 list matrix into `NULL`. On a
`POSIXlt` value, it recurses with no end. The trial write in
`messages_write_fault()` runs bare jsonlite, so it can pass a body that
httr2 then sends in another form.

One helper writes the body with `jsonlite::toJSON(auto_unbox = TRUE,
digits = 22, null = "null")`. It attaches the text with
`httr2::req_body_raw(type = "application/json")`. The seven
`req_body_json()` sites in `R/` use it. `messages_write_fault()` writes
through the same helper. The roxygen and NEWS change to match. The
candidate row on the `POSIXlt` recursion closes with this milestone.

**Out:**
- Which data-frame rows count as empty does not change. A row whose only
  field is a zero-cell array column still aborts. M046 changes that rule.
- A number that jsonlite writes as a string is M045.
- An `httr2::obfuscated()` value in `...` now fails with the jsonlite
  error "No method asJSON S3 class: httr2_obfuscated". Only httr2
  internals can reveal it, and the package puts its token in a header. No
  candidate row.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [ ] AC1: `lms_chat_openai()` sends each `messages` value below as the
      text that `jsonlite::toJSON()` writes from
      `list(model = "a-model", messages = value)`. The options are
      `auto_unbox = TRUE`, `digits = 22`, and `null = "null"`. A test
      compares the raw text of the recorded request body with that write.
      Six values are frames with the columns `role = c("user", "user")`
      and `content = c("Hi", "Yo")` plus one column:
      - a 2-by-0 numeric matrix
      - a 2-by-0 list matrix
      - a 2-by-3-by-0 array
      - a data-frame column whose one column is a 2-by-0 numeric matrix
      - a `POSIXlt` column
      - a 2-by-2 numeric matrix, which main already sends this way

      Three values are list-form messages with one extra field:
      - a `POSIXlt` value
      - a data frame whose one column is a 2-by-0 numeric matrix
      - a list whose first element is a `POSIXlt` value
- [ ] AC2: `lms_chat_native()`, `lms_chat_openresponses()`, `lms_embed()`,
      `lms_load()`, `lms_download()`, and `lms_unload()` each send a
      `POSIXlt` value given in `...` as the text that jsonlite writes from
      it. A test reads the field in the raw text of each recorded body.
      After the change, `grep -rn 'req_body_json' R/` finds no line.
- [ ] AC3: The roxygen of `messages_write_fault()` and of the new helper
      states this. The trial write and the sent body go through one helper
      with the same options. So a `messages` value that passes the trial
      write is sent as jsonlite writes it. NEWS.md has one entry for the
      change. It names three effects. A zero-width matrix or array column
      of a `messages` data frame is now sent. A `POSIXlt` value no longer
      fails with infinite recursion. An `httr2::obfuscated()` value in
      `...` now aborts. No milestone numbers appear.
- [ ] AC4: `devtools::document()` leaves the tree clean, and
      `devtools::test()` passes. `devtools::check()` gives 0 errors and 0
      warnings, and each note has a reason.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T3
- AC4 → T4

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. -->

- [ ] T1: Write the AC1 test "messages reach the request as jsonlite
      writes them" in `tests/testthat/test-arg-guards.R` and the AC2 test
      "a POSIXlt value in the dots reaches each request" beside the
      wrapper tests. Read the raw body from `httr2::req_dry_run()`, because
      `request_target()` parses it. Call `lms_load()` with `force = TRUE`,
      or give it a response for its `list_models()` call. Wrap each call
      that can recurse on main in `setTimeLimit()` or a subprocess, so the
      red run ends. Confirm that each AC1 value but the 2-by-2 matrix and
      each AC2 function is red on main.
- [ ] T2: Add the helper, use it at the seven sites, and route
      `messages_write_fault()` through it. Put one site back to
      `req_body_json()` in a scratch copy and see its AC2 case go red.
- [ ] T3: Update the roxygen that AC3 names, including the
      `req_body_json()` mention at `R/utils-args.R:389`, and NEWS.md. Run
      `devtools::document()`.
- [ ] T4: Run `devtools::test()` and `devtools::check()`. The check needs
      `RLMSTUDIO_API_TOKEN` and a started server (LESSONS, M009).

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-09-28: created by /milestone-plan. Absorbs two candidate rows: the zero-extent array column (M042 findings O4 and P2) and the zero-column data-frame column (RR01 finding B1).
- 2026-09-28: criteria audit (full mode, fresh [O] reader) returned four findings, all fixed. AC1 gained a nested zero-width matrix and a character matrix. AC1 and AC2 now state behavior and name the test as the procedure. The AC3 help sentence changed, because the `{}` wording was false for `{"l":null}`.
- 2026-09-28: plan gate chose to keep M040's recursion, so a data-frame column with no columns counts as empty, over counting every data-frame column as a field value, because both write the same `{}` as a nested row of `NA` cells that M040 refuses; falsified by a server that answers a message holding only `{}` fields as a normal message.
- 2026-09-28: /milestone-implement started on branch `m044-openai-messages-cell-free-rows` and stopped at T2, because the goal is wrong. The plan probed bare `jsonlite::toJSON()`. The request goes through httr2 1.3.0, whose `unobfuscate_rec()` rebuilds each list in the body with `x[] <- lapply(x, ...)`. On a data frame, that turns a zero-width matrix or array column into `NA` and a 2-by-0 list matrix into `NULL`. `httr2::req_dry_run()` shows row 2 of the AC1 frames sent as `{}` or `{"x":null}`, which is the empty message the empty-row rule refuses. So today's abort is right for five of the six AC1 frames. The nested frame is sent as `{"x":{}}`, which M040's rule counts as empty. Status back to planned for a re-cut.
- 2026-09-28: the branch holds the T1 tests (`a1fb74e`, cleaned in `e3b521b`), which assert the false premise. It is unpushed. The re-cut decides whether to delete it. Two leads for the re-cut: `messages_write_fault()` runs bare `jsonlite::toJSON()` and not httr2's walk, so the trial write can pass a body that httr2 sends in another form. The `POSIXlt` recursion in the candidate rows can have the same cause.
- 2026-09-28: re-cut by /milestone-plan. The goal, scope, criteria, and tasks above replace the first plan, and the file moved from `M044-openai-messages-cell-free-rows.md`. The first plan's rule moved to M046. Probes on 2026-09-28 compared bare jsonlite with httr2's walk: zero-width matrix, array, and list-matrix columns and `POSIXlt` values differ, and 17 other shapes match. Absorbs the `POSIXlt` candidate row (M043 T1).
- 2026-09-28: criteria audit (full mode, fresh [O] reader) returned ten findings. Seven were fixed. The AC2 grep gained `-r`. The obfuscated-value claim was false and became a stated change. AC1 gained a list-form data-frame field and a `POSIXlt` in a list. AC3's wording now names the shared helper. Test names moved to T1. Two passed, and a logical 2-by-0 matrix was not added.
- 2026-09-28: plan gate chose to write the body with jsonlite and send it raw over running httr2's walk in the trial write, because the walk is httr2 internals and drops zero-width columns with no message. Falsified by an httr2 release that exports a body writer with no walk, or by a user who needs an `obfuscated()` value in a body.
- 2026-09-28: plan gate chose all seven body sites over `lms_chat_openai()` alone, because a `POSIXlt` value in `...` recurses at each site. Falsified by a site whose server rejects the text that jsonlite writes but accepts httr2's form.
- 2026-09-28: plan gate deleted the unpushed branch `m044-openai-messages-cell-free-rows`. Its tests are at `a1fb74e` and `e3b521b` while git keeps the objects.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

## Review
<!-- owner: review · exclusive. -->
