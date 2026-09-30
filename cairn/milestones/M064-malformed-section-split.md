# M064: Each help page shows the malformed-reply rules that its function applies

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** user-facing — it changes the help pages of exported functions and one error message of `lms_chat_openresponses()`.
- **Branch/PR:** m064-malformed-section-split

## Goal

If a function raises `rlmstudio_bad_response` under a malformed-reply rule, itself or through a call, its page shows that rule's section and no other.

## Scope

**In:**
- Split the "Malformed response" section of `R/conditions.R` (lines 105 to 284 at plan time) into six sections of the `rlmstudio-conditions` topic. "Malformed response" keeps the text on every page: what the class is, the functions that raise it, a body that does not parse as JSON, and the `status` field. "Malformed model list", "Malformed load or download reply", "Malformed embeddings", "Malformed chat reply", and "Malformed logprobs" take the rest. The text moves with no change in meaning.
- Change the `@inheritSection` lines of each exported function to the AC1 table.
- Point each reference to a section at the section that now holds the text. Among the references to text that the split moves are `R/conditions.R:296`, `:341`, `:349`, and `R/serve.R:756` on the `lms_server_ready()` page. Text that renders on the conditions page cannot link to that page. There, a reference to a section that a page lacks links to a function page that holds the section, or the sentence is reworded. Remove the two links from the topic to itself.
- Remove the sentence on the `rlmstudio_reply_cut_off` warning from the malformed text (`R/conditions.R:252`). The "Cut-off reply" section already states the warning and its link to the abort.
- Split rule 5 of the logprobs rules into two rules with one message each: a `top_logprobs` that is not an array, and a candidate that is not a JSON object. The list then has seven rules. The help, the internal note above `check_part_logprobs()` (`R/chat.R:1147`), and the tests follow.
- The "Server not running" section lists the functions that raise `rlmstudio_bad_response` for a model list with another shape (`R/conditions.R:49`). Add the model-list lookup of `lms_chat_openai()` and `lms_chat_openresponses()` to that list. Also name it in the note above `rlm_abort_bad_reply()` (`R/utils-api-error.R:177`).
- One NEWS.md entry.

**Out:**
- A split of the "Server not running" and "API failure" sections, which also carry batch and embedding paragraphs to every page. It becomes a candidate row.
- A split below the level of a section. For example, the `list_models()` page keeps the two extra rules of `list_instances()`, and the `lms_chat_native()` page keeps the `choices` rules. No row.
- The other six model-name cases of that candidate row stay in it.
- A shipped test that reads the layout of the help pages. The AC1 to AC4 procedures run at review. No row.

## Acceptance criteria

- [ ] AC1: Run `devtools::document()`. Then for each title in the table below, take the set of files in `man/` that hold `\section{<title>}`. That set is exactly `rlmstudio-conditions.Rd` and the files that the row names. The procedure is `grep -l '\\section{<title>}' man/*.Rd`, run once for each of the ten titles.

  | Title | Pages other than `rlmstudio-conditions` |
  |---|---|
  | Server not running | `list_instances`, `list_models`, `lms_chat`, `lms_chat_batch`, `lms_chat_native`, `lms_chat_openai`, `lms_chat_openresponses`, `lms_download`, `lms_download_status`, `lms_embed`, `lms_load`, `lms_unload`, `lms_unload_all` |
  | API failure | the same 13 pages |
  | Malformed response | the same pages less `lms_unload` |
  | Malformed model list | `list_instances`, `list_models`, `lms_chat`, `lms_chat_batch`, `lms_chat_openai`, `lms_chat_openresponses`, `lms_load`, `lms_unload_all` |
  | Malformed load or download reply | `lms_download`, `lms_download_status`, `lms_load` |
  | Malformed embeddings | `lms_embed` |
  | Malformed chat reply | `lms_chat`, `lms_chat_batch`, `lms_chat_native`, `lms_chat_openai`, `lms_chat_openresponses` |
  | Malformed logprobs | `lms_chat`, `lms_chat_batch`, `lms_chat_openresponses` |
  | Cut-off reply | `lms_chat`, `lms_chat_batch`, `lms_chat_openai` |
  | Reply from another model | `lms_chat`, `lms_chat_batch`, `lms_chat_openai`, `lms_chat_openresponses` |

- [ ] AC2: Each phrase of the form `"<title>" section` in a file in `man/`, with line breaks read as spaces, resolves. A phrase resolves in two cases. In the first, the same file holds `\section{<title>}`. In the second, the words after the phrase are "of" and a link. The topic or alias of the link belongs to another file in `man/`, and that file holds the section. The procedure is a script that reads every file in `man/`. It prints each phrase that does not resolve, and it prints none. It also prints the number of phrases it read, which is more than zero. The same script reads the roxygen text of each file in `R/`, with its `#'` lines joined. It lists each phrase that names one of the six titles that start with "Malformed". At review, each listed phrase is read, and each one points at text that the named section holds.
- [ ] AC3: `grep -cE 'link(\[=)?\{?rlmstudio(-conditions|_(no_server|api_error|bad_response|reply_cut_off|model_mismatch))' man/rlmstudio-conditions.Rd` prints 0.
- [ ] AC4: `grep -l 'reply_cut_off' man/*.Rd` lists exactly `lms_chat.Rd`, `lms_chat_batch.Rd`, `lms_chat_openai.Rd`, and `rlmstudio-conditions.Rd`.
- [ ] AC5: This criterion covers `lms_chat_openresponses()` with `simplify = TRUE` and `logprobs = TRUE`. Take a step whose `top_logprobs` is a string, a number, `true`, or a JSON object, empty or not. The step is the first step, or it comes after good steps. The call aborts with `rlmstudio_bad_response`, and its message holds "The `top_logprobs` of a `logprobs` step is not an array." in each case. Take a `top_logprobs` array that holds a string, a number, `true`, an array, or `null` as a candidate, first or after a good candidate. The call aborts with `rlmstudio_bad_response`, and its message holds "A candidate in `top_logprobs` is not a JSON object." in each case. The "Malformed logprobs" section lists the two faults as two rules. In `R/conditions.R`, each `rule <n>` or `rules <n>` sits in the section that holds its numbered list. It names the rule that it means in the seven-rule list. NEWS.md has one entry for the message and the help change.
- [ ] AC6: The "Server not running" section names `lms_chat_openai()` and `lms_chat_openresponses()` in its list of functions that raise `rlmstudio_bad_response` for a model list with another shape. It says that they do so through the model lookup, with either setting of `simplify`, and that `lms_chat()` raises it through them. A test calls each of the two functions with a reply from another model. The model list that follows breaks a model-list rule. The test asserts `rlmstudio_bad_response` with `simplify = TRUE` and with `simplify = FALSE`.
- [ ] AC7: `devtools::test()` reports 0 failures and 0 errors. `devtools::check()`, run with `RLMSTUDIO_API_TOKEN` set, reports 0 errors and 0 warnings.

## Coverage

- AC1 → T2, T3
- AC2 → T2, T4
- AC3 → T2, T4
- AC4 → T2, T4
- AC5 → T1, T2, T5
- AC6 → T2, T4
- AC7 → T5

## Tasks

- [x] T1: In `tests/testthat/test-chat.R:341`, give `logprobs_rule_messages` seven entries, with the two new rule 5 messages. Renumber the old R5 and R6 labels, which about 10 lines of `test-chat.R` use. Add the AC5 cases to `logprobs_breaks()` (`tests/testthat/helper-chat-bodies.R:219`). Each rule test asserts its own message and asserts that the message of each other rule is absent, as `expect_logprobs_rule()` does. See the tests red on main. Then split `abort_top_logprobs()` in `check_part_logprobs()` (`R/chat.R:1182`) into the two messages, and renumber the rules in the note above it (`R/chat.R:1147`). Plant the old message for the candidate case and see the test go red (M026 lesson).
- [x] T2: In `R/conditions.R`, move the text of the "Malformed response" section into the six AC1 sections. Move sentences whole. Change only three things: references to other sections, rule numbers, and pointers such as "of either kind above" (line 190) to text that the split moves. Fix the four references that the Scope names. Remove the cut-off sentence at line 252 and the self-links at lines 253 and 264. Add the AC6 sentence to the "Server not running" section, outside its `simplify = TRUE` clause. Update the rule 5 text of the logprobs list to the two rules of T1.
- [x] T3: Change the `@inheritSection` lines to the AC1 table: `R/chat.R:112`, `:302`, `:599`, `:1400`, `:1930`, `R/embed.R:93`, `R/list.R:39`, `:222`, `R/load.R:82`, `R/download.R:28`, `:183`, and `R/unload.R:99`. Keep each tag on one line with the title exact (M007 lesson). Run `devtools::document()` and the ten AC1 greps.
- [x] T4: Write the AC2 script in the scratchpad, not in the package. Plant one phrase that names a section its page lacks and see the script print it. Run it over `man/` and fix each phrase it prints. Run the AC3 and AC4 greps. Name the model lookup in the note above `rlm_abort_bad_reply()` (`R/utils-api-error.R:177`). The AC6 test exists at `tests/testthat/test-model-check.R:514` for both routes, with `simplify = TRUE` alone. Add the `simplify = FALSE` case.
- [x] T5: Add the NEWS.md entry. Set `RLMSTUDIO_API_TOKEN`, then run `devtools::test()` and `devtools::check()`.

## Work log

- 2026-09-30: created by /milestone-plan from the user's pick of the logprobs help candidate row. At plan time the logprobs rules reach 13 help pages, not the four that the row names. Nine of them are for functions that never check the rules.
- 2026-09-30: criteria audit (full mode, fresh Opus reader), pass 1, returned 9 findings. Seven were fixed without a question. They were the title count, four stale references, the link and rule-number forms of AC2, and the AC3 alias pattern. The others were the `true` and `{}` probes in AC5, the test claim moved from AC5 to T1, and the task citations. The Goal was reworded to sections, because a split below a section is out. The model-list rules on the chat pages went to the gate.
- 2026-09-30: plan gate chose a split of the "Malformed response" section alone over a split of all three shared sections. The other two carry less text that a page cannot use, and the split of all three can need a second milestone. Falsified by a user who misreads a batch or embedding paragraph on a page where it does not apply.
- 2026-09-30: plan gate chose the "Malformed model list" section on the four chat pages that read the model list over a link to the `list_models()` page. Each page then states every rule its call can break. Falsified by a user who finds the chat pages too long to read.
- 2026-09-30: plan gate chose two messages for rule 5 over one message and a help-only change. Each other rule has one message per fault. Falsified by a script that matches the old message text.
- 2026-09-30: plan chose review-time greps and a scratchpad script over a shipped test that reads the help layout. The layout is not behavior, and `man/` is absent under R CMD check. Falsified by a layout fault that ships after this milestone.
- 2026-09-30: criteria audit pass 2 (full mode, new fresh Opus reader) returned 8 findings, all fixed without a question. AC2 now reads `R/` with joined lines and checks each "Malformed" title. AC3 lists the five aliases. AC5 says "holds", adds the step position, and checks rule numbers. AC6 adds `simplify = FALSE` and `lms_chat()`. The Goal now names the raise, because `lms_server_ready()` applies the rules but raises nothing.
- 2026-09-30: implement gate chose to split the "other messages ... name `simplify = FALSE`" sentence into a chat copy in "Malformed chat reply" and an `lms_embed()` copy in "Malformed embeddings", over moving it whole. This bends T2's "move sentences whole" for that one sentence. It also chose `lms_chat_openai()` as the link target for a "Reply from another model" reference on a page that lacks the section.
- 2026-09-30: T1 done. Rule 5 is now two rules with one message each, and the old rule 6 is rule 7. The tests went red on the old code, and a plant of the old message on the candidate case gave 61 failures. `devtools::test()`: 0 failures, 0 errors, 3 skips.
- 2026-09-30: T2 done. A sentence diff of the old and new text shows reference, rule-number, and pointer changes. It also shows the gated message split, the rule 5 split, and the removed cut-off sentence. The `lms_chat_openresponses()` argument text now says seven rules and names the section. `devtools::test()`: 0 failures, 0 errors.
- 2026-09-30: T3 done. The ten AC1 greps match the table, and a planted wrong row shows FAIL. `devtools::test()`: 0 failures, 0 errors.
- 2026-09-30: T4 done. The AC2 script is at the session scratchpad `ac2.py`. Two planted phrases printed as unresolved. On `man/` it read 93 phrases with 0 unresolved and listed 6 R/ phrases. The `lms_server_ready()` phrase resolved but pointed at the wrong section, so it now names "Malformed model list" of `list_models()`. AC3 prints 0 (2 on main). AC4 lists the four pages. The lookup test now covers `simplify = FALSE`. `devtools::test()`: 0 failures, 0 errors.
- 2026-09-30: T5 done. One NEWS.md entry with two sub-items. With `RLMSTUDIO_API_TOKEN` set, `devtools::test()` gave 0 failures, 0 errors, 3 skips, and `devtools::check()` gave 0 errors, 0 warnings, 0 notes.

## Decisions

## Review
