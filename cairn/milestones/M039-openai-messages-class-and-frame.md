# M039: The OpenAI chat function sends a classed messages list and refuses a data frame with a bad column name or an empty row

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4
- **Resolves:** —
- **Surface tier:** user-facing — it changes what the exported `lms_chat_openai()` sends and refuses
- **Branch/PR:** m039-openai-messages-class-and-frame

## Goal

`lms_chat_openai()` sends a `messages` list that has a class attribute at
the outer level or on a message. It refuses a data frame that jsonlite sends
with empty or renamed messages, before the server probe.

## Scope

**In:** The check in `R/utils-args.R` reads `messages` as the caller passed
it. The call builds the request body without the class attribute of a list
that is not a data frame. It also removes the class of each element. Two new data-frame
rules, each with one detail text: a column rule (no columns, or a column
name that is `NA`, empty, or repeated) and an empty-row rule. Help at
`messages`, NEWS, and tests.

**Out:** A class below the message level, such as a classed `content` value
or a classed data-frame column, still reaches jsonlite. It becomes a new
candidate row. A recursive rule must allow the classes jsonlite can write,
such as `I()`, `Date`, and `factor`. Repeated field names inside a
list message stay unchecked, because no finding reported them.

## Acceptance criteria

- [ ] AC1: When `messages` is a list that is not a data frame, the check
      reads the value as passed, so a data frame or a `POSIXlt` value as a
      message still aborts with the rule-4 text. After the check, the call
      removes the class attribute of the outer list and of each of its
      elements, and of nothing below them. The sent `messages` field of a
      value with a class at those two levels equals the field sent for the
      same value with no class. The tests vary the position: the outer list,
      the first message, a later message, and both levels at once. They
      also vary the form: one S3 class, a class vector of two entries,
      `"list"`, and `I()`. A
      field wrapped in `I()`, such as `role = I("user")`, is sent as the
      array `["user"]`, as before. A `content` list with an S3 class still
      fails in jsonlite, as before, because its class reaches jsonlite.
- [ ] AC2: The call keeps the class vector of a data frame `messages`
      value. Probes built with `structure()` for the class vectors
      `c("tbl_df", "tbl", "data.frame")` and `c("foo", "data.frame")` are
      sent as one message per row, and they meet the AC3 rules. The call
      does not remove the class of a data-frame column. jsonlite handles it.
- [ ] AC3: If a data frame `messages` value breaks one of two rules, the
      call aborts before the server probe, with no condition class. The column
      rule: it has no columns, or a column name that is `NA`, empty, or
      repeated. Its detail text is "You gave a data frame that has no
      columns or a column name that is missing or repeated.". The empty-row
      rule: a row `i` for which `all(is.na(value)[i, ])` is `TRUE`, with the
      data-frame method of `is.na()`. Its detail text is "You gave a data
      frame with a row in which every cell is NA.". Each abort holds its own
      detail text and no other rule's detail text. The call checks the
      column rule first, so a data frame with no columns gets the column
      text alone. The column-rule probes
      are rows with zero columns, a column named `NA`, a column named `""`,
      and two columns of the same name. The empty-row probes put `NA` in a
      character, a numeric (`NaN` too), a factor, a `Date`, and a list
      column. They put it at the first, a middle, and the last row, and in
      a data frame of one row. A data frame that keeps both rules still
      reaches the request. Two such probes are near the line. One has an
      `NA` cell in every row. One has a row with one cell that is not `NA`.
- [ ] AC4: The help of `lms_chat_openai()` at `messages` and NEWS.md state
      the class removal at the two levels, that a class below them is not
      removed, that a data frame and its columns keep their classes, and the
      two data-frame rules.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T3
- AC4 → T4

## Tasks

- [x] T1: Write the tests first in `tests/testthat/test-arg-guards.R`. Add
      the two rule texts to `messages_rule_details` as `rule5` and
      `rule6`. Add the AC3 probes to `messages_probes`. Add the AC1 and AC2
      values to the `passes` table of the test "a messages value that keeps
      every rule reaches the request". Add a rule-4 probe for a `POSIXlt`
      message. Make sure that the new tests fail on main.
- [x] T2: In `lms_chat_openai()` (`R/chat.R:377`), build the body from the
      value with its class removed at the two levels. Leave a data frame
      alone. Plant a regression: remove the class removal, and make sure
      that the AC1 tests go red.
- [x] T3: Add the two data-frame rules to `messages_fault()`
      (`R/utils-args.R:366`), ahead of the `nrow()` return. Plant a wrong
      detail text and make sure that the rule test goes red.
- [x] T4: Update the `messages` help at `R/chat.R:268-282` and add a NEWS
      item. Run `devtools::document()`, `devtools::test()`, and
      `devtools::check()` with the token from memory set.

## Work log

- 2026-09-27: created by /milestone-plan.
- 2026-09-27: criteria audit (full mode, fresh [O] reader) returned ten findings. The draft took eight fixes. The check comes before the class removal, and the removal stops at two levels. `I()` on a field stays. The probes vary position and form. A classed data frame stays. `is.na()` defines the empty row. The criteria bind the function, and they name the two texts. Two findings went to the gate.
- 2026-09-27: second audit pass (full mode, same reader) on the gate-changed criteria returned five findings, all fixed. The column rule runs first. AC2 names two `structure()` probes and leaves a column class to jsonlite. AC1 adds a classed `content` probe. AC4 covers the data-frame classes.
- 2026-09-27: plan gate chose to remove the class after the check over refusing any class but `AsIs`, because no value that serializes today is refused; falsified by a classed list whose class carries meaning the server needs.
- 2026-09-27: plan gate chose to refuse repeated column names over leaving them to jsonlite, because jsonlite renames them without a message; falsified by a user who relies on the `.1` rename.
- 2026-09-27: T1 done. The new probes and pass cases are in `tests/testthat/test-arg-guards.R`. On main, the rule test fails at the first data-frame probe, which reaches the server probe, and the pass test fails in jsonlite at the first classed list. The below-level test passes on main, as it must. The test-first red is expected until T2 and T3.
- 2026-09-27: T2 done. `unclass_messages()` in `R/utils-args.R` removes the class of the outer list and of each message, and `lms_chat_openai()` builds the body from it after the check. Two plants went red: with no removal, the pass test failed in jsonlite, and with a removal one level deeper, the `I()` field case and the below-level test failed. The rule test stays red until T3.
- 2026-09-27: T3 done. `data_frame_messages_fault()` in `R/utils-args.R` applies the column rule, then the empty-row rule, which counts the cells that are not `NA` per row. Two plants went red: a wrong detail text, and the empty-row rule placed first, which gave the zero-column probe the wrong text. `devtools::test()` passes.
- 2026-09-27: T4 done. The `messages` help and NEWS state the class removal, the kept classes, and the two data-frame rules. `devtools::document()` warns only on the known `@aliases` line (candidate row). `devtools::check()` gave 0 errors, 0 warnings, 0 notes.
