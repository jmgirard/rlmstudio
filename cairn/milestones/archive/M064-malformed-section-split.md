# M064: Each help page shows the malformed-reply rules that its function applies

**Status:** done (2026-09-30, PR #64 https://github.com/jmgirard/rlmstudio/pull/64).

**Goal:** If a function raises `rlmstudio_bad_response` under a malformed-reply
rule, itself or through a call, its page shows that rule's section and no other.

**Outcome:** The "Malformed response" section of R/conditions.R became six
sections: "Malformed response", "Malformed model list", "Malformed load or
download reply", "Malformed embeddings", "Malformed chat reply", and
"Malformed logprobs". Each exported function's `@inheritSection` lines take
only the sections its function applies. `check_part_logprobs()` in R/chat.R
splits rule 5 into two messages, so the logprobs list has seven rules. "Server
not running" and the note above `rlm_abort_bad_reply()` name the model lookup
of `lms_chat_openai()` and `lms_chat_openresponses()`. Section references
resolve on every page, and the conditions topic no longer links to itself.

**Decisions:** none cross-cutting. The plan gate kept "Server not running" and
"API failure" whole, with a candidate row. It put the model-list section on
the four chat pages that read the model list.

**Review:** Three lenses, all seven criteria passed on the first pass. The
gate fixed 5 findings. They covered the NEWS entry, three long lines, a note on
where a bad lookup body aborts, and a model-list pointer on the chat pages.
Four were rejected as planned or out of scope.
