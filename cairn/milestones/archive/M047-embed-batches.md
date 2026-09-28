# M047: The embedding function sends a long input in batches

**Status:** done (2026-09-28, PR #47 https://github.com/jmgirard/rlmstudio/pull/47)

**Goal:** `lms_embed()` splits its input into requests of at most
`batch_size` texts and shows progress across them.

**Outcome:** `lms_embed()` gains `batch_size = 100` and `quiet = NULL` after
`...`, and `rlm_check_batch_size()` checks the size before the server probe.
The function sends one request per batch in input order and checks the server
before each request. A bad reply, or a status other than 401, 403, or 404,
leaves that batch's rows `NA`. The call then warns once past `quiet`. If every
request fails, the call aborts with the first failure. Three faults abort: a
401, 403, or 404, a lost server, and a width change under `simplify = TRUE`.
After a success, the abort carries `results`. `simplify = FALSE` returns a
list with one body per request.
A progress bar counts inputs. The help pages, the conditions page, and NEWS
match.

**Decisions:** D-024 records the three differences from `lms_chat_batch()`.

**Review:** All seven criteria passed. The history and prior-review lenses
found nothing. The diff lens gave 11 findings. The gate fixed O1 to O8 (docs,
the width message for one input, five tests and three test fixes). O9 became
D-024, O11 a candidate row, and O10 was rejected. One LESSONS line extended.
