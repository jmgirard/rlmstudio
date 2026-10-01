# M077: A chat continues a thread from the reply itself

**Status:** done (2026-10-01, PR #77 https://github.com/jmgirard/rlmstudio/pull/77)

**Goal:** A user continues a stored chat thread with `previous_response_id = first`, where `first` is the reply of the earlier call.

**Outcome:** `rlm_check_response_id()` reads `attr(value, "response_id", exact = TRUE)`. When the attribute is there, it is checked with `id_fault()` and sent as a plain string in place of the value. This covers `lms_chat()`, `lms_chat_native()`, `lms_chat_openresponses()`, and the `...` of `lms_chat_batch()`. A bad attribute aborts before the server probe with no class, and the message names the argument and the attribute. With `api_type = "openai"`, a value that carries an id is refused as a string is. A value with no attribute is sent as the id itself. So a reply with no id gets status 400, and an empty or blank reply text aborts locally. Ten tests in `test-thread.R` cover the change. The help of the four functions and NEWS describe it. The `follow-up` chunk of `vignette("chat-options")` passes `first` and was knitted live.

**Decisions:** D-039 (read the attribute, no class on the reply text).

**Review:** Fan-out of three fresh reviewers. They reported 12 findings and no code bug. Three were fixed at the gate. They were help and NEWS on an empty or blank reply text, the roxygen wrap and OpenAI sentence, and the API reference note. Follow-up: the second "given as a single string" headline joins the M060 candidate row. Eight rejected with reasons in the Review section of the branch file. The M018 lesson is extended to `attr()`.
