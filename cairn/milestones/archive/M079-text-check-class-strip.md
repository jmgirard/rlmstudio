# M079: The text checks strip a class before they read a name, and their tests turn a sending site red

**Status:** done (2026-10-01, PR #79 https://github.com/jmgirard/rlmstudio/pull/79)

**Goal:** A classed name, id, or type filter gets the check, the match, and the message of its plain form.

**Outcome:** `strip_class()` runs in `id_fault()` and `type_fault()` after the type test. It calls `unclass()` and then `asS4(, FALSE, complete = FALSE)`, and it keeps names and `dim`. `rlm_check_type()` returns the filter with no attributes, and `list_models()` and `list_instances()` match with it. A text fault in `model`, `job_id`, `previous_response_id`, or its `response_id` attribute gets the headline "must be a string of valid text". A `text_rule` attribute on the `id_fault()` detail marks it. `lms_chat()` runs `rlm_check_route_dots()` after `rlm_check_schema()`, as the batch does. The fault and send probes use three trap classes: S3, S4, and S4 of a `setOldClass()` class. Other tests give both list functions a classed filter. They also read the sent value of each passing dot, a shortened `instr` dot, and the check order on both routes. NEWS.md has three entries.

**Decisions:** D-041 (class strip and plain type filter). Implement chose the headline without "or `NULL`" for `previous_response_id`.

**Review:** Fan-out of three fresh reviewers, with 13 findings. Five were fixed at the gate. With its default `complete = TRUE`, `asS4()` put back the `.S3Class` of an S4 class built on a `setOldClass()` class. A class method then still ran in the check. NEWS.md and the AC5 test gained the `messages` dot on "openai", and a comment was narrowed. AC2 gained an instance `config` case, and the loops that the branch added were nested. The subtests named by function alone stayed, as the file's convention. Seven history notes were rejected or noted. At hygiene, the M060 follow-up row narrowed to the C locale gap, and the M049 lesson gained `complete = FALSE`.
