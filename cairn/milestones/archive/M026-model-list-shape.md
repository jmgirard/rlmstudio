# M026: A model list with the wrong JSON shape aborts with rlmstudio_bad_response

**Status:** done (2026-09-22, PR #26 https://github.com/jmgirard/rlmstudio/pull/26)

**Goal:** `list_models()`, `lms_unload_all()`, and `lms_server_ready()` read a
status-200 model list through one shape check.

**Outcome:** `model_list_fault()` in `R/list.R` checks the unsimplified parse
against four rules before any filter. `models` is an array of objects. `type`
and `key` are strings, and `loaded_instances` is an array. `size_bytes` is a
number, absent, or `null`. Each instance `id` is a string with content.
`list_models()` aborts with `rlmstudio_bad_response`, and `lms_unload_all()`
and `lms_load()` without `force` abort through it. `lms_server_ready()` calls
the check in place of `is_model_list()`, which is gone. `{"models": []}` gives
an empty data frame. `lms_unload_all()` reads `id` alone, without the old
`identifier` and first-column fallbacks. Help page and four NEWS entries.

**Decisions:** D-017 records the field-type checks and the `id`-only read.

**Review:** One pass, three-lens fan-out, user-facing tier. All seven criteria
passed. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes once the
local server was on. The history and prior-review lenses found nothing. The
diff lens found no code bug and ranked 11 test and doc gaps. Finding 1, a
message test that did not fail for a wrong message on a non-object entry, was fixed at the gate.
Findings 2 to 8, 10, and 11 were rejected or covered, and 9 was noted.
