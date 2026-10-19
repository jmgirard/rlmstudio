# M093: list_instances tests for a two-kind field and an empty display name

**Status:** done (2026-10-19, PR #96 https://github.com/jmgirard/rlmstudio/pull/96)

**Goal:** Tests pin two `list_instances()` cases that the code handles today with no test, and a live reply checks the help sentence about the fields that only `lms ps --json` gives.

**Outcome:** Two tests in `tests/testthat/test-list-instances.R`. A config
field of one number and one string gives the list-column `list(8192L,
"auto")`. A `display_name` of `""` stays `""`. A live reading on LM Studio
0.4.26+4 found none of the `lms ps` keys `status`, `queued`, `ttlMs`, and
`lastUsedTime` in `/api/v1/models`, so the help still names the four as
missing. Each loaded instance there carries `remaining_ttl_seconds`, and the
`list_instances()` help now says that the function does not read it. The help
also says that an empty display name stays `""`. No NEWS entry.

**Decisions:** none.

**Review:** Four-lens fan-out, 11 findings: 7 fixed (the two help sentences,
the regenerated `.Rd`, the candidate row wording, the API reference note), 4
rejected. Check clean, CI green on all jobs. Narrowed the row "list_instances
fields and tests" to the four fields.
