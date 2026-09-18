# M005: One abort path for the seven REST failure branches

**Status:** done (2026-09-18, PR #6 https://github.com/jmgirard/rlmstudio/pull/6)

**Goal:** One abort path for every REST wrapper that handles a failed response.

**Outcome:** `R/utils-api-error.R` holds `rlm_abort_api(resp, label)`,
`api_error_message(resp)`, and `is_message_string(x)`. All seven wrappers named
by `grep -rn "req_error(is_error" R/` call it, and their four separate
extraction blocks are gone. The abort carries the class `rlmstudio_api_error`
and a `status` field holding the status as an integer. The message reads
`error`, then `error$message`, and subsets `error` only when it is a list,
which is the check that fixed the crashes. A body that does not parse to a list
gives the body text, and anything else gives `HTTP Status <n>`. Below status
400 the body text comes first, for `lms_load()`, which aborts on a 200 that
does not report the model as loaded. `tests/testthat/test-api-error.R` drives
22 body shapes at two statuses against all seven.

**Decisions:** One entry, kept in git. A JSON body with no readable message
gives the status and not the body, which trades GP4 and D-003.

**Review:** Three-lens fan-out. The blame-history and prior-review lenses found
no regression. The diff-bug lens reported 16 findings, each verified before
triage, and none met the return floor. Seven were fixed now, four became rows,
one was absorbed, and four were rejected.
