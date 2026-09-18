# M006: list_models() joins the shared REST abort path

**Status:** done (2026-09-18, PR #7 https://github.com/jmgirard/rlmstudio/pull/7).

**Goal:** `list_models()` reports a failed REST response through
`rlm_abort_api()`, the path the other seven REST wrappers already use.

**Outcome:** `R/list.R` turns the httr2 error policy off and calls
`rlm_abort_api(resp, "API List Failed")` on any status other than 200. That
range is wider than the httr2 default, which errors only at 400 and above. The
abort carries the class `rlmstudio_api_error` and an integer `status` field.
`list_models` joined `api_error_callers`, and the shared failure table in
`tests/testthat/test-api-error.R` now drives eight wrappers over 22 body
shapes at two statuses. The driver matches the message tail with `endsWith()`
in place of a fixed substring `grepl()`. The source-grepping coverage guard in
that file was deleted, and a replacement is a candidate row. `test-list.R`
gained a path assertion, and `NEWS.md` a bullet.

**Decisions:** none cross-cutting. The plan gate chose deleting the coverage
guard over hardening it, and an ends-with match over a substring match.

**Review:** three lenses. Only the diff-bug lens reported findings, nine of
them. Three wrong statements were fixed on the branch, two in `NEWS.md` and one
in a roxygen comment. Two became candidate rows and three were rejected. The
claim that the deleted guard never gated a merge was falsified, then corrected in the ROADMAP row and the M005 lesson.
