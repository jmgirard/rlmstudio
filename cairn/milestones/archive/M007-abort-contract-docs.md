# M007: The abort contract reaches the help pages

**Status:** done (2026-09-18, PR #8 https://github.com/jmgirard/rlmstudio/pull/8)

**Goal:** Every exported function calling an abort helper documents the class it raises, and one topic page states the contract.

**Outcome:** A doc-only roxygen block in `R/conditions.R` produces the
`rlmstudio-conditions` topic, aliased under `rlmstudio_no_server` and
`rlmstudio_api_error` so `?<class>` reaches it. Its sections `Server not
running` and `API failure` reach eleven exports through `@inheritSection`: the
ten holding the `stop_if_no_server()` and `rlm_abort_api()` sites, plus
`lms_chat()`. `lms_chat()`, `lms_chat_batch()`, and `lms_unload_all()` carry a
`@details` sentence naming the function they reach an abort through; the latter
two also say they raise `rlmstudio_no_server` themselves first. `NEWS.md` and a
pkgdown `Error Conditions` section gained entries. No runtime change: the only
non-comment line added across `R/` is the block's anchoring `NULL`.

**Decisions:** none milestone-local. The plan gate chose one `@inheritSection`
source topic over eleven copies, and a promise bounded to two named greps.

**Review:** Two passes. Pass one returned on AC5: a roxygen2 upgrade to 8.1.0
made `devtools::document()` rewrite `DESCRIPTION`, failing the no-diff clause.
Pass two passed all six criteria and a clean gate. A three-lens fan-out returned
eight findings, three actioned (missing class aliases; two delegation sentences
omitting the directly raised `rlmstudio_no_server`) and five rejected.
