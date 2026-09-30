# M061: A named store argument on the thread chat routes

**Status:** done (2026-09-30, PR #61 https://github.com/jmgirard/rlmstudio/pull/61).

**Goal:** A user turns off the storage of chat replies from R with a checked
`store` argument on the native and OpenResponses routes, in one call and in a
batch.

**Outcome:** `lms_chat()`, `lms_chat_native()`, and `lms_chat_openresponses()`
take `store = NULL` after `...`. `rlm_check_flag(store, null_ok = TRUE)` runs
before the probe, and `store_field()` sends `isTRUE(store)` or no field.
`rlm_check_store_route()` aborts on a flag with `api_type = "openai"` in
`lms_chat()` and `lms_chat_batch()`, which also checks `args[["store"]]`
before its probe. The thread cassettes were re-recorded, because the body
order and so the request hash changed. `lms_chat_openai()` still sends a
`store` in `...` unchecked.

**Decisions:** D-035 (a named `store`, sent as a plain flag, refused on the
OpenAI route).

**Review:** Three lenses, all seven criteria passed on the first pass. The
gate fixed three help gaps. It restored the cross-route `store = FALSE`
reply-id sentence that M058 T8 had added. It fixed the `NULL` wording of the
`?lms_chat` param and named the unchecked `store` on `?lms_chat_openai`. Six findings were rejected and one
noted. A CI job failed on an r2u mirror timeout, and its rerun passed.
