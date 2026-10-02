# M079: The text checks strip a class before they read a name, and their tests turn a sending site red

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4
- **Resolves:** —
- **Surface tier:** user-facing — it changes the aborts, the type filter match, and the check order of exported functions.
- **Branch/PR:** m079-text-check-class-strip

## Goal

A classed name, id, or type filter gets the check, the match, and the message of its plain form.

## Scope

**In:**
- `id_fault()` and `type_fault()` (R/utils-args.R:183, R/utils-args.R:1509) remove the class and the S4 bit before they read the value. Today a class method for `[`, `[[`, `length`, `dim`, or `is.na` runs inside the check. It can replace the package abort or change its detail.
- `rlm_check_type()` returns the plain vector, and `list_models()` and `list_instances()` match with it. Today `%in%` matches a classed filter through its `as.character()` method.
- `plain_probes` in `tests/testthat/test-name-faults.R` gains the two classes of AC1.
- `tests/testthat/test-chat-dot-clash.R` reads the value of each passing dot in the batch bodies, takes the `api =` form, and pins a shortened `instr` dot.
- `lms_chat()` runs `rlm_check_route_dots()` after `rlm_check_schema()`, as `lms_chat_batch()` does.
- A text fault in `model`, `job_id`, `previous_response_id`, or a `response_id` attribute gets the headline "must be a string of valid text".
- The stale comment of `check_reply_model()` on classed names, help, NEWS.md, one D-entry, and tests.

**Out:**
- In a C locale, `validEnc()` passes an unmarked byte `0xff`. This stays in the candidate row "Follow-ups to the text and plain-string checks of M060". Post-merge hygiene narrows that row to it.
- A test that the body list holds a plain string before it is written. The plan gate dropped it, because jsonlite drops names and the S4 bit, so the wire shows a plain string.
- The call-site guard of `test-name-faults.R` reads only `name <- function` definitions. This limit goes to DESIGN.md Known issues in the plan commit.
- The `type` headline "given as a character vector" stays as it is.

## Acceptance criteria

- [x] AC1: The test values are of two classes. One is an S3 class whose methods for `[`, `[[`, `length`, `dim`, and `is.na` raise an error. The other is an S4 subclass of `"character"` whose S4 methods for the same five functions raise an error. Take each pair of `name_pairs` in `tests/testthat/test-name-faults.R`. Each fault probe, given in each class, gets the message of its plain form, compared with `identical()`. The fault probes are the bad-text probes of that file, `NA_character_`, `""`, and `" "`. The pairs other than `type` also take a value of length two. For the `type` pair, the class is set on the whole vector. Each `valid_cafe` form, given in each class, reaches the server check with one probe call. `devtools::test()` shows it.
- [ ] AC2: The `as.character()` method of an S3 class returns another type name. The model list holds an llm and an embedding model. `list_models(type =)` and `list_instances(type =)` give a `type` filter of that class the rows of its plain form. If the embedding model has a malformed instance entry, `list_instances()` gives that filter the outcome of its plain form. A test of each case shows it.
- [x] AC3: Take each pair of `plain_pairs` in `tests/testthat/test-name-faults.R`, and the value `"m"` in each class of AC1 and in each of the four `plain_probes`. The call sends the name as `"m"`, in the body field or the URL path that the pair reads. `devtools::test()` shows it.
- [x] AC4: Take each case of `passing_cases` in `tests/testthat/test-chat-dot-clash.R`. `lms_chat()` and `lms_chat_batch()` send the dot's name with the dot's value in each request body. The batch runs with the route given as `api_type =` and as `api =`. A second call gives `system_prompt = "S"` and a dot `instr = "Be brief."` on the `"openresponses"` route. `lms_chat()` and `lms_chat_batch()` raise no error, and each request body holds `"instructions":"S"` and `"instr":"Be brief."`. `devtools::test()` shows it.
- [x] AC5: The call gives an `instructions` dot on the `"openresponses"` route and one other fault. The other fault is a bad `model`, a bad `input` or `inputs`, or a `schema` that `rlm_check_schema()` refuses. `lms_chat()` and `lms_chat_batch()` abort with a headline that names the other argument and not `instructions`. A test of each of the six combinations shows it.
- [x] AC6: Take each pair of `name_pairs` other than the `type` pair. Each bad-text probe aborts with a headline that names the argument and holds "must be a string of valid text". For each `previous_response_id` pair, each bad-text probe in the `response_id` attribute gets the same headline, naming the attribute. No such headline holds "given as a single string". `devtools::test()` shows it.
- [x] AC7: `devtools::test()` gives 0 failed. `devtools::check()` with `RLMSTUDIO_API_TOKEN` set gives 0 errors, 0 warnings, and 0 notes.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T4
- AC5 → T5
- AC6 → T6
- AC7 → T7

## Tasks

- [x] T1: In `id_fault()` and `type_fault()`, remove the class and the S4 bit before the first call that can dispatch. Keep the `dim` attribute that the array rule reads, and never call `as.character()`. Add the AC1 tests to `test-name-faults.R`. Give the S3 class its own name, because `send_pair()` mocks `as.character.foo`. Write the S4 methods with the full signatures of each generic. In a scratch copy, undo the strip and make sure that the AC1 tests go red.
- [x] T2: `rlm_check_type()` returns the plain vector, and `list_models()` (R/list.R:70) and `list_instances()` (R/list.R:247) reassign `type`. Add the AC2 tests to `test-list-args.R`. The `type` help of both functions says that a classed filter matches by its value, as D-041 states.
- [x] T3: Add the two AC1 classes to `plain_probes`, and keep the `as.character()` mock of `send_pair()`. In a scratch copy, remove the `plain_string()` reassignment at one body-field site and make sure that a probe goes red.
- [x] T4: In `test-chat-dot-clash.R`, read the value of each passing dot in every request body. Run the batch with `api =` as well, and add the `instr` test of AC4.
- [x] T5: In `lms_chat()` (R/chat.R:155), move `rlm_check_route_dots()` after `rlm_check_schema()`. Add the six AC5 tests to `test-chat-dot-clash.R`.
- [x] T6: Give a text fault the headline of AC6 in `rlm_check_id()` (R/utils-args.R:17) and in both headlines of `rlm_check_response_id()` (R/utils-args.R:395). Update the tests that expect the old headline, and add the AC6 tests, the attribute probes included.
- [x] T7: Fix the `check_reply_model()` comment on classed names (R/chat.R:917). Add NEWS.md entries for the type filter, the check order, and the headline. Run `devtools::document()`, `devtools::test()`, and `devtools::check()` with `RLMSTUDIO_API_TOKEN` set.

## Work log

- 2026-10-01: created by /milestone-plan. Absorbs the candidate row "Follow-ups to the text and plain-string checks of M060", promoted at the 2026-10-01 triage.
- 2026-10-01: criteria audit, full mode, two passes by a fresh Opus reader. Pass 1 returned findings on AC1, AC2, AC3, AC4, AC6, and AC7. Pass 2 returned four wording fixes on AC1, AC2, AC3, and AC7. Each was fixed before the plan commit. The two dot-body criteria then merged into AC4, with no change in wording, to stay under the split tripwire.
- 2026-10-01: plan gate chose no test of the unwritten body list over such a test, because jsonlite drops names and the S4 bit. Falsified by a body writer that keeps either one.
- 2026-10-01: plan gate kept the call-site guard as it is over deleting or hardening it, because each call site today is a top-level function. Falsified by a call site that the guard misses.
- 2026-10-01: plan chose to move the route-dot check of `lms_chat()` after `schema` over moving the batch check earlier. The batch reads the route from its dots only after `rlm_chat_dots()`. Falsified by a dot fault that must outrank a `model` fault.
- 2026-10-01: implement started on branch m079-text-check-class-strip. Question gate chose the short headline "`<arg>` must be a string of valid text." for T6, with no "or `NULL`" on `previous_response_id`.
- 2026-10-01: T1 done. `strip_class()` runs in `id_fault()` and `type_fault()` after the type test. The AC1 tests failed on "trap method ran" before the fix. In a scratch copy with the `type_fault()` strip removed, only the four `type` tests went red. `devtools::test()`: 0 failed, 3 skipped.
- 2026-10-01: T2 done. `rlm_check_type()` returns the filter with no attributes, and both list functions reassign `type`. The three AC2 tests failed before the fix. `devtools::test()`: 0 failed, 3 skipped.
- 2026-10-01: T3 done. `plain_probes` holds the two trap classes, and `send_pair()` installs their methods. In a scratch copy with the `model` reassignment of `lms_chat_openai()` removed, its send test went red on "No method asJSON S3 class: foo", and with the trap probes alone on "No method asJSON S3 class: rlmTrap". `devtools::test()`: 0 failed, 3 skipped.
- 2026-10-01: T4 done. The passing-dot test reads the dot value in every body, and the batch runs with `api_type =` and `api =`. In a scratch copy with a wrong expected `instructions` value, 10 body checks failed. `devtools::test()`: 0 failed, 3 skipped.
- 2026-10-01: T5 done. `lms_chat()` runs `rlm_check_route_dots()` after `rlm_check_schema()`. Before the move, the three `lms_chat()` cases failed on the `instructions` headline, and the three batch cases passed. `devtools::test()`: 0 failed, 3 skipped.
- 2026-10-01: T6 done. `id_fault()` marks a text fault with a `text_rule` attribute, and `rlm_check_id()` and both `rlm_check_response_id()` headlines read it. No existing test read the old headline for a text fault. The 14 AC6 tests failed before the fix. The headline tests read the `message` field of the error. The full message wrapped the attribute headline in an `Rscript` run, and `rlang` is not a declared dependency. `devtools::test()`: 0 failed, 3 skipped.
- 2026-10-01: T7 done. The `check_reply_model()` comment says that both callers pass the plain string. NEWS.md has three entries: the class strip with the type filter, the text headline, and the check order. `devtools::document()` gave no diff, `devtools::test()` with `RLMSTUDIO_API_TOKEN` set gave 0 failed and 3 skipped, and `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- claim audit: 30 claims read, 0 corrected — NEWS.md, R/chat.R, R/list.R, R/utils-args.R, man/list_models.Rd, man/list_instances.Rd, tests/testthat/test-chat-dot-clash.R, tests/testthat/test-list-args.R, tests/testthat/test-name-faults.R
- 2026-10-01: implement complete, status set to review.
- 2026-10-01: review in progress. AC1 and AC3 to AC7 verified and ticked. AC2 waits for the gate, and two of three reviewers are still running.

## Decisions

## Review

Fresh runs on 2026-10-01 at 471fc0d, origin/main an ancestor of the branch. `devtools::test()` with `RLMSTUDIO_API_TOKEN` set: 22666 passed, 0 failed, 0 errors, 3 skipped (live tests, LM Studio not running).

- AC1: `test-name-faults.R` runs two tests for each of the 16 `name_pairs`. The classes are the S3 class `rlmTrap` and the S4 class `rlmTrapString`, each with error methods for the five generics. "gives a classed fault the message of its plain form" compares the messages with `identical()`. Its probes are NA, "", " ", the five text probes, and two values, or the classed whole vector for `type`. "passes classed valid text to the server check" gives each `valid_cafe` form one probe call. A separate test shows that each trap method raises its error. The file: 98 tests, 3427 passed, 0 failed.
- AC2 (not yet ticked): `test-list-args.R` shows that `rlmOtherType` gives "embedding" through `as.character()` and that `%in%` reads it. "a classed type filter gets the rows of its plain form" runs `list_models()` and `list_instances()`. Each gives the classed and the plain filter the row of `m1`, compared with `identical()`. The malformed case of "a classed type filter gets the instance outcome of its plain form" gives the embedding model a `display_name` of 5. That is a field of the model, not of an entry in its `loaded_instances`. A scratch probe on 2026-10-01 gave an instance a `config` of 5. The plain and the classed filter got the same one-row frame, and the "embedding" filter got `rlmstudio_bad_response`. No suite test holds that case, so the box waits for the gate.
- AC3: "sends each probe as the plain string \"m\"" runs for each of the 14 `plain_pairs`. A set test pins them to the AC1 pairs other than `type`. `plain_probes` holds the four earlier probes and the two AC1 classes, each with the value "m". Each request body carries `"<field>":"m"`, read by a pattern and by `jsonlite::parse_json()`. For `job_id`, the URL path ends in `/m`. All pass in the run above.
- AC4: In `test-chat-dot-clash.R`, "the dot on another route is sent as a field, with no abort" runs the four `passing_cases`. It parses each request body and compares the dot's value with `expect_identical()`. It runs `lms_chat()` (1 request) and `lms_chat_batch()` (2 requests), and the batch takes the route as `api_type =` and as `api =`. "a shortened instr dot is sent beside the system prompt" gives `system_prompt = "S"` and `instr = "Be brief."` on "openresponses". Both functions raise no error, and each body holds `"instructions":"S"` and `"instr":"Be brief."`. The file: 6 tests, 135 passed, 0 failed.
- AC5: "another argument fault comes before the clashing dot" gives `instructions = "Be brief."` on "openresponses" and one other fault. The fault is a `model` of 1, an `input` or `inputs` of `NA_character_`, or a `schema` of 1. That makes six calls over `lms_chat()` and `lms_chat_batch()`. Each headline matches "^`<arg>` must " and does not hold "instructions", with no probe call. It passes in the run above. The T5 work-log line records the three `lms_chat()` cases red before the move.
- AC6: "gives a text fault the text headline" runs for the 14 pairs other than `type`, with the five text probes. It reads the `message` field of the error, which holds the headline alone. Each headline names the argument, holds "must be a string of valid text", and does not hold "given as a single string". For the four `previous_response_id` pairs, each probe also goes in the `response_id` attribute, and the headline names "The `response_id` attribute of `previous_response_id`". All pass in the run above, in a UTF-8 locale.
- AC7: `devtools::test()` gave 0 failed (the run above). `devtools::check()` with `RLMSTUDIO_API_TOKEN` set gave 0 errors, 0 warnings, and 0 notes.

Consistency gate: `cairn_validate.py` exit 0, all checks passed. No principle text changed, so `cairn_impact` was skipped. `devtools::document()` left no diff. The branch adds no file and does not touch README.Rmd or README.md. The repo has no pkgdown site. NEWS.md has three entries, with no milestone number: the class strip with the type filter, the text headline, and the check order.
