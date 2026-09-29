# M056: Test failures that name each broken function and reply check

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — the deliverable is test code, which no user of the package runs
- **Branch/PR:** m056-test-failure-isolation

## Goal

Each broken function or reply check in three test areas shows as its own
test failure.

## Scope

**In:** Three candidate rows, merged at the plan gate. The 16 loops over
function names in `tests/testthat/test-arg-guards.R` each define one
`test_that()` block per function. An error in one function then no longer
ends the block for the others. The live id-column test in
`test-list-instances.R` stops turning a refused model-list request into a
skip. M055 applied the same rule to the live embedding tests. On 2026-09-29,
`grep -rn 'skip(' tests/testthat` found no other skip inside an
`rlmstudio_api_error` handler. `helper-chat-bodies.R` gains a null-item shape
and a null-part shape. With them, a swap of two adjacent reply checks changes
the detail sentence and does not crash on `"a"[["type"]]`.

**Out:** About 30 `for (name in ...)` loops in nine other test files have the
same flaw. So do the inner loops over probe values in `test-arg-guards.R`.
Both go to one new candidate row. The answer-text checks sit in
`join_reply_texts()`, apart from the four pairs of AC4, so their order stays
outside this milestone.

## Acceptance criteria

- [ ] AC1: Each loop that `grep -nE '^  for \(name in '
      tests/testthat/test-arg-guards.R` lists at commit 65d6bd4 (16 loops)
      runs as one `test_that()` block per function name. Each block's
      description contains that name. The same grep on the branch lists no
      line.
- [ ] AC2: Take a scratch copy of the branch. In it, `lms_download_status()`
      aborts with `stop("planted")` in place of its identifier check. No
      function in `R/` calls it (grep of `R/` on 2026-09-29).
      `testthat::test_file()` on `test-arg-guards.R` then reports at least
      one failed or errored block. Every such block names
      `lms_download_status` as a whole word in its description. Each block
      that names another function that `guarded_exports(c("model",
      "job_id"))` returns passes.
- [ ] AC3: The live test "live: the id column holds the instance ids of the
      model list" in `tests/testthat/test-list-instances.R` calls
      `list_models()` with no handler for `rlmstudio_api_error`. A refused
      model-list request then fails the test and does not skip it. Its
      comment no longer says that a refused request skips.
- [ ] AC4: Four pairs of consecutive `if` checks call
      `rlm_abort_bad_response()` in `R/chat.R`. They are output/item and
      item/message in `chat_message_items()`, and content/part and
      part/output_text in `responses_text_parts()`. For each pair, one shape
      from `native_unreadable()` or `responses_unreadable()` breaks both
      checks, and neither check crashes on it.
      `test-chat.R` asserts the detail sentence of that shape. Swap the pair
      in a scratch copy. That shape alone then raises an
      `rlmstudio_bad_response` whose message contains the detail sentence of
      the check that now runs first.
- [ ] AC5: `devtools::test()` reports no failure. `devtools::check()` gives 0
      errors, 0 warnings, and no note that main at 65d6bd4 does not give.

## Coverage

- AC1 → T1
- AC2 → T1, T2
- AC3 → T3
- AC4 → T4
- AC5 → T5

## Tasks

- [x] T1: In `test-arg-guards.R`, move each of the 16 loops outside its
      `test_that()`, so that it defines one block per function name with the
      name in the description. Setup calls such as `local_guard_only()` move
      into each block. Rewrite comments that describe a block as covering
      every function.
- [x] T2: Run the AC2 plant in a scratch copy of the branch. Make sure that
      the run holds blocks for the other functions of the domain before you
      trust its green. Log the failed and passed block counts.
- [ ] T3: In `test-list-instances.R` near line 410, remove the `tryCatch()`
      that skips on `rlmstudio_api_error`. Rewrite the comment above it.
- [ ] T4: Add "an item that is null" to `shared_unreadable()`, with first
      check `item`. Add "a part that is null" to `responses_unreadable()`,
      with first check `part`. Give both their entries in the check maps of
      `helper-chat-bodies.R`. Run the four swaps of AC4 in a scratch copy,
      each on the shape that pins it, and log the detail each raises. The
      batch tests at `test-chat-batch.R:608` and `test-chat-batch-usage.R:450`
      reuse these shapes, so run them too.
- [ ] T5: Run `devtools::test()` and `devtools::check()`. If `check()` gives a
      note, run it on 65d6bd4 to compare.

## Work log

- 2026-09-29: created by /milestone-plan. It merges three candidate rows: M013 review finding 7, M021 review finding O6, and M055 review finding O9.
- 2026-09-29: criteria audit, reduced mode (internal tier), by a fresh [O] reader. Two findings, both fixed before the gate. AC2 moved its plant from `lms_chat`, which `lms_chat_batch` calls, to `lms_download_status`, and asks for a whole-word name. AC4 became a property of one shape per check pair. The reason is that the string shapes crash under a swap and end the shape loop before later shapes run.
- 2026-09-29: plan gate chose one `test_that()` block per function over a wrapper helper. The helper turns an unexpected error into a failure that names the function. It must tell an expectation failure from an error, and both have class `error`, so it needs its own test. Falsified by a run where per-function blocks hide a failure that the helper shows.
- 2026-09-29: T1 done. The 16 loops now sit at top level and define 117 blocks in the file. `ttl_domain()` no longer calls `fail()`, because a `fail()` outside a block ends the file. Its missing-call check moved into the ttl domain test. A plant that removes `lms_embed` from `ttl_calls` failed that test and the two `lms_embed` ttl blocks. `devtools::test()` with the token: 635 blocks, 0 failed, 0 errored, 0 skipped.
- 2026-09-29: T2 done. In a scratch copy, `stop("planted")` replaced `rlm_check_id(job_id, "job_id")` in `lms_download_status()`. `test_file()` ran 117 blocks, and 3 failed: the bad-id, omitted-id, and server-down blocks of `lms_download_status`, each naming it as a whole word. The other 9 functions of the domain passed all their blocks, from 4 (`lms_download`, `lms_load`, `lms_unload`) to 16 (`lms_chat`).

## Decisions

## Review
