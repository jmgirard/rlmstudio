# M034: The OpenAI chat and embedding functions take a ttl for a model that the request loads

**Status:** done (2026-09-27, PR #34 https://github.com/jmgirard/rlmstudio/pull/34)

**Goal:** A chat or embedding request that loads a model takes a named,
checked `ttl` for the idle seconds that the model stays loaded.

**Outcome:** `lms_chat_openai()`, `lms_embed()`, and `lms_chat()` take `ttl`
and send it as a JSON integer. `rlm_check_ttl()` accepts `NULL` or one whole
number from 1 to `.Machine$integer.max`. `rlm_check_ttl_route()` aborts a
`ttl` on the other routes of `lms_chat()` and `lms_chat_batch()`. Both run
before the server probe. `lms_load()` stays out, because its endpoint
rejects `ttl`. A live check on LM Studio 0.4.25+1 showed the TTL.

**Decisions:** D-020 records both checks as an exception to D-003.

**Review:** One pass, three-lens fan-out. All six criteria passed, and
`devtools::check()` was clean. Two lenses found nothing. The diff-bug lens
found 7 items, and the gate fixed 5. They were the conditions page, an open
substring match, an unrecorded default in three help texts, D-020, and a
stale reference line. It rejected 2: a value loop that
the delegate's check masks, and classed numerics. The M008 lesson gained
the anchored-match point.
