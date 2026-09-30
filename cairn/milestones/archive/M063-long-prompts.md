# M063: A load above the trained context warns, and the help says how to fit a long prompt

**Status:** done (2026-09-30, PR #63 https://github.com/jmgirard/rlmstudio/pull/63).

**Goal:** A user with a prompt longer than the loaded context learns from R
how LM Studio treats it and how far a larger `context_length` can go.

**Outcome:** With `force = FALSE`, `lms_load()` reads the full model list and
calls `warn_context_above_max()` in R/load.R. A `context_length` above the
row's `max_context_length` warns with class `rlmstudio_context_above_max`, past
`rlmstudio.quiet`, and the load still goes out. `model_list_fault()` requires
`max_context_length` to be a number, absent, or `null`. The "Long prompts"
help section on `lms_load()`, inherited by `lms_chat()`, covers the overflow
error, the warning, the rejected `rope_frequency_scale` field, and
`input_tokens`. Probe facts: cairn/references/lmstudio-api-surface.md. Tests:
test-long-prompts.R and new rows in test-model-list-shape.R.

**Decisions:** D-037 (a load above the model-list maximum warns past quiet,
and `max_context_length` gets a type rule).

**Review:** Three lenses, all seven criteria passed on the first pass. The
claim audit corrected 5 of 59 claims. The gate fixed 6 of 14 findings, among
them the NEWS scope, the warning text, and a coercion test. The shared-check
placement and exact key matching went to one candidate row. Five findings were
rejected, and one was noted.
