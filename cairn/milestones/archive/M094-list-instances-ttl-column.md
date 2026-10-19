# M094: list_instances remaining ttl column

**Status:** done (2026-10-19, PR #97 https://github.com/jmgirard/rlmstudio/pull/97)

**Goal:** `list_instances()` returns each instance's `remaining_ttl_seconds`.

**Outcome:** `list_instances()` in `R/list.R` has a fifth column,
`remaining_ttl_seconds`, a double read from each instance in
`/api/v1/models`, `NA` where absent or `null`. The zero-row frame has it, and
a config field of that name becomes `config.remaining_ttl_seconds`.
`instance_list_fault()` adds a third rule: the field is a number, absent, or
`null`, else `rlmstudio_bad_response`. A live probe on LM Studio 0.4.26+4 found
the field on a `--ttl` load and no field on a load with no ttl. The cassette
was re-recorded with gemma loaded with a ttl. Help, NEWS, data-raw README, and
the API reference note were updated.

**Decisions:** none cross-cutting. The plan gate kept the four `lms ps`
fields out, chose the server name, and put the column fifth. AC6 was
narrowed at the user's choice after two re-audits.

**Review:** Four-lens fan-out, 19 findings: 5 fixed (README ttl load, NEWS
column shift, generator header, a redundant `as.double()` and its comment), 1
follow-up (`Inf` passes the number rule, absorbed into the row "list_instances
fields and tests"), 10 rejected, 3 noted. Check clean, CI green on all jobs.
Narrowed that row to the four `lms ps` fields and the `Inf` case.
