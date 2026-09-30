# M060: Names that are not plain text, and dots that lms_chat() sets

**Status:** done (2026-09-30, PR #60 https://github.com/jmgirard/rlmstudio/pull/60).

**Goal:** Three kinds of argument value get a correct outcome before any
request, in place of a wrong message or an error from R or jsonlite.

**Outcome:** `text_fault()` and `text_fault_at()` run before the whitespace
`grepl()` in `id_fault()` and `type_fault()`. A string that fails
`validEnc()` or is marked `"bytes"` aborts with its own detail before the
probe. `rlm_check_id()` and `rlm_check_response_id()` return `plain_string()`
(`unclass(x)[[1]]`), and the 10 sending sites reassign it. `lms_load()` and
`lms_unload()` return the plain string. `rlm_check_route_dots()` aborts on an
`instructions` dot on the openresponses route and a `messages` dot on the
openai route. It runs in `lms_chat()`, and before the probe in the batch. Help, NEWS,
and the R/conditions.R fault list were updated.

**Decisions:** D-034 (the text rule and plain string for checked names, and
the abort on a dot that `lms_chat()` sets).

**Review:** Pass 1 returned the milestone once on AC4, because the batch
`previous_response_id` help lacked the rule sentences. Pass 2 ran three
lenses, and all five criteria passed. The gate fixed five findings: a NEWS
overclaim, an extra "or", the dot-abort headline, two long lines, and the
help order. Twelve went to one candidate row. Five were rejected. The M049
lesson grew.
