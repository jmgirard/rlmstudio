# M060: Names that are not plain text, and dots that lms_chat() sets

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3, GP4
- **Resolves:** —
- **Surface tier:** user-facing — it changes the aborts, the sent values, and two return values of exported functions.
- **Branch/PR:** —

## Goal

Three kinds of argument value get a correct outcome before any request, in place of a wrong message or an error from R or jsonlite.

## Scope

**In:**
- A name, id, or type filter that is not valid text aborts with its own detail. Today `id_fault()` (R/utils-args.R:164) and `type_fault()` (R/utils-args.R:1242) report the byte `0xff` as "whitespace only", with two `grepl()` warnings.
- A name or id that carries a class, names, or the S4 bit is sent as a plain string. Today `structure("m", class = "foo")` fails in jsonlite after the server check, `I("m")` is sent as `["m"]`, and a classed `"already_downloaded"` misses the test at R/download.R:202.
- `lms_chat()` and `lms_chat_batch()` abort on an `instructions` dot on the OpenResponses route and on a `messages` dot on the OpenAI route. Today R raises "formal argument matched by multiple actual arguments", in the batch after the server check.
- Help, NEWS.md, the R/conditions.R fault list, one D-entry, and tests.

**Out:**
- `input`, `inputs`, `system_prompt`, and the text in `messages` that is not valid UTF-8. jsonlite sends each bad byte as U+FFFD. This goes to a new candidate row.
- A shortened dot such as `instr` goes to the request body as an unknown field, as D-003 states. No row.
- An `lms_chat()` argument that the caller gives twice keeps R's own error, as M059 decided. No row.

## Acceptance criteria

- [ ] AC1: Take the 16 pairs of function and argument that follow. `model` of `lms_chat()`, `lms_chat_batch()`, `lms_chat_openresponses()`, `lms_chat_openai()`, `lms_chat_native()`, `lms_embed()`, `lms_load()`, `lms_download()`, and `lms_unload()`. `job_id` of `lms_download_status()`. `previous_response_id` of `lms_chat()`, `lms_chat_openresponses()`, `lms_chat_native()`, and `lms_chat_batch()`, where it is a dot. `type` of `list_models()` and `list_instances()`. In a UTF-8 locale, each pair aborts before the check for a running server on each of five probes. Two probes are the byte `0xff` with no encoding mark and marked `"UTF-8"`. The third is the string `"a"` followed by the byte `0xff`, marked `"UTF-8"`. For these three, the message names the argument and says that the string is not valid in its encoding. The last two probes are the byte `0xff` and the UTF-8 bytes of `"café"`, each marked `"bytes"`. For these two, the message names the argument and says that the string is marked as bytes. No message contains "whitespace", and no call gives a warning. For `type`, each probe also runs as the second element of `c("llm", probe)`, and the message names element 2. The string `"café"` passes each pair's check in three forms: marked `"latin1"`, marked `"UTF-8"`, and with no mark.
- [ ] AC2: Take the 14 pairs of AC1 other than `type`. Each pair passes and sends a plain string for each of four probes that hold the value `"m"`. The first probe is a string with the class `"foo"`, where an `as.character()` method for `"foo"` returns another value. The others are `I("m")`, a string with a name, and an S4 object that contains `"character"`. For each probe, the body field that carries the argument is the JSON string `"m"`. That field is `model`, `instance_id` for `lms_unload()`, or `previous_response_id`, and for `job_id` the URL path ends in `m`. `lms_load()` sends its load body for a model that is not loaded. It returns the plain string `"m"` on that path and on the already-loaded path. `lms_unload()` returns the plain string `"m"`. With the server check mocked to pass, `lms_download_status()` with an `"already_downloaded"` job id of class `"foo"` returns the already-downloaded status and sends no HTTP request.
- [ ] AC3: `lms_chat()` aborts on two dots in its `...`: a dot named exactly `instructions` with `api_type = "openresponses"`, and a dot named exactly `messages` with `api_type = "openai"`. The message names the argument and says what `lms_chat()` sets it from. It does not contain "matched by multiple actual arguments". The abort has no condition class and sends no request. `lms_chat()` gives it for `instructions` also with no route given. `lms_chat_batch()` gives the same abort before the check for a running server. It does so with the route given as `api_type`, as `api`, and, for `instructions`, with no route given. `instructions` with `api_type = "openai"` or `"native"` and `messages` with `api_type = "openresponses"` or `"native"` do not give this abort.
- [ ] AC4: The help of each function in AC1 states that the argument must be valid in its declared encoding and not marked `"bytes"`. The help of each function in AC2 also states that a class, names, and the S4 bit are removed before the value is sent. The `@return` text of `lms_load()` and `lms_unload()` says that the returned name is a plain string. The `...` help of `lms_chat()` and `lms_chat_batch()` states the AC3 abort. NEWS.md has an entry for each of AC1, AC2, and AC3, and the AC2 entry names the new return value of `lms_load()` and `lms_unload()`. The list of argument faults in the "Server not running" section of R/conditions.R names the AC1 encoding and bytes faults and the AC3 abort.
- [ ] AC5: `devtools::test()` and `devtools::check()` pass with no errors, warnings, or notes.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T4
- AC5 → T5

## Tasks

- [ ] T1: Write the AC1 tests first and see them red on main. Add one text rule shared by `id_fault()` and `type_fault()`. It rejects a string for which `validEnc()` is `FALSE`. It rejects a string marked `"bytes"` with its own detail, because jsonlite cannot write it. It runs before the whitespace `grepl()`. Add a guard test that searches `R/` for calls to `rlm_check_id()`, `rlm_check_response_id()`, and `rlm_check_type()`. It passes on the call sites that the AC1 list covers and fails on a new one.
- [ ] T2: Write the AC2 tests first and see them red on main. Make `rlm_check_id()` and `rlm_check_response_id()` return `unclass(x)[[1]]` (M049 lesson). Reassign the value only in the functions that send it: R/chat.R:256, 260, 561, 1307, 1310, R/embed.R:114, R/load.R:73, R/download.R:49, 198, and R/unload.R:46. `lms_chat()` and `lms_chat_batch()` send nothing themselves, so they keep the check alone (M003 lesson). In a scratch copy, remove each reassignment in turn and see a test go red.
- [ ] T3: Write the AC3 tests first and see them red on main. Add a route check of the dots. Call it in `lms_chat()` after `match.arg()`, and in `lms_chat_batch()` after the route is read (R/chat.R:1830) and above `stop_if_no_server()` (R/chat.R:1877). Add a guard test that walks the body of `lms_chat()`. It takes the arguments passed by name to a route function, less the formals of `lms_chat()`. It expects `instructions` and `messages` alone.
- [ ] T4: Update the help, NEWS.md, and the fault list in R/conditions.R. Run `devtools::document()`. Append one D-entry. A checked name or id must be valid text and is sent as a plain string, which annotates D-031. `lms_chat()` aborts on a dot that it sets itself, which narrows D-003 as D-023 did.
- [ ] T5: Set `RLMSTUDIO_API_TOKEN` (M009 lesson). Then run `devtools::test()` and `devtools::check()`.

## Work log

- 2026-09-29: created by /milestone-plan from two candidate rows. One is the encoding and class faults of `id_fault()` and `type_fault()` (M052 review finding O3, M058 review finding Q5). The other is the `instructions` and `messages` dots of `lms_chat_batch()` (M059 review finding R12).
- 2026-09-29: criteria audit (full mode, fresh [O] reader), pass 1, returned 9 findings, all fixed without a question. Added probes for no mark, a mixed string, and element 2. Listed the 16 pairs and moved the search to a T1 guard. Limited the reassignment to the functions that send. Stated the `lms_load()` and `lms_unload()` return values. Limited the class sentence to sent arguments. Required "not valid text" in R/conditions.R. Added a D-entry task. Named the two AC3 pairs, moved the body walk to a T3 guard, and added a batch probe on the default route.
- 2026-09-29: criteria audit pass 2 (full mode, new fresh [O] reader) on the final wording returned 9 findings, all fixed without a question. AC1 adds UTF-8 and unmarked `"café"` as passing forms and gives the bytes mark its own detail and probe. AC2 names the body field, the two `lms_load()` paths, a mocked server check, and an `as.character()` method on the class probe. AC3 adds `lms_chat()` with no route. AC4 defines the text rule and requires the `@return` change.
- 2026-09-29: plan gate chose to send a classed name as a plain string over an abort on any class, because glue and S4 strings work today. Falsified by a server field that needs the JSON form a class gives, such as the array from `I()`.
- 2026-09-29: plan gate chose an abort for an `instructions` or `messages` dot over a dot that replaces what `lms_chat()` builds. A replacing dot drops `system_prompt` with no message. Falsified by a user who needs to pass their own `instructions` or `messages` through `lms_chat()`.

## Decisions

## Review
