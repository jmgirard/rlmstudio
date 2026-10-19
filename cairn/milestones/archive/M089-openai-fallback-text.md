# M089: The OpenAI batch vector fallback names what it cannot store

**Status:** done (2026-10-18, PR #92 https://github.com/jmgirard/rlmstudio/pull/92).

**Goal:** On the OpenAI route, the warning of a `logprobs = TRUE` vector batch that returns a list names what the vector format cannot store, and the help says where that warning comes among the batch warnings.

**Outcome:** `vector_fallback` in `lms_chat_batch()` (`R/chat.R`) has an
OpenAI branch: "The vector format cannot store the `<lms_chat_result>`
replies of the openai route. Returning list." The OpenResponses text
"cannot store logprobs dataframes" is unchanged, and the return stays the
list (plan gate choice). `?lms_chat_batch` says that with `simplify = TRUE`
and `logprobs = TRUE` the vector format warns and returns the list, that
quiet does not hide it, and that the reason is a line of the failed-inputs
warning when an input failed, else its own warning before any cut-off or
no-logprobs warning. New tests in `test-batch-native-logprobs.R` cover both
quiet values, the option, a schema, a cut-off reply, a failed input first
and last, and an OpenResponses failed input. One NEWS sentence.

**Decisions:** none.

**Review:** 6 criteria verified. The criteria audit fixed 7 findings at the
plan, and the claim audit corrected 3 of 19 claims. Three lenses gave 18
findings: 11 fixed, 2 follow-up (new row "openresponses fallback text"),
5 rejected. CI green on the first wait. Graduated the row "openai batch
fallback text".
