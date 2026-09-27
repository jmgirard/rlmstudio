# M031: A chat batch stops at an API failure that holds for every input

**Status:** done (2026-09-27, PR #31 https://github.com/jmgirard/rlmstudio/pull/31)

**Goal:** `lms_chat_batch()` aborts at the first input that fails with
status 401, 403, or 404, and the abort carries the replies so far.

**Outcome:** The `rlmstudio_api_error` handler of `lms_chat_batch()` is now
`keep_or_abort_api()`. For status 401, 403, or 404 it calls
`abort_with_results()`, which the lost-server handler now shares. The
condition then carries a `results` field by the lost-server rule. Any other
status and every `rlmstudio_bad_response` still fail their own input alone.
The batch help, the "API failure" section of `rlmstudio-conditions`, and one
NEWS entry changed to match. A live check (T1) found 401 for a bad token on
all three routes. It found 404 for a missing model on `/api/v1/chat` only.
The OpenAI-style routes answer 200 or 400, and a candidate row holds that.

**Decisions:** D-019 (narrows D-011, annotates D-015).

**Review:** One pass, three-lens fan-out, user-facing tier. All five criteria
passed, and `devtools::check()` was clean. Two lenses found nothing. The
diff-bug lens found 8 minor items. The gate fixed 5: test `info` labels, a
no-backtrace check, an abort message check, a help rewrap, and a NEWS reason.
It rejected 3. A candidate row holds the route note, and D-019 chose 403. No
criterion asks for a stop test with `simplify = FALSE` or a `schema`.
