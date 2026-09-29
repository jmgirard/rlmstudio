# M051: A schema data-frame batch returns one column per schema property

**Status:** done (2026-09-29, PR #51 https://github.com/jmgirard/rlmstudio/pull/51).

**Goal:** With an object `schema` and `format = "data.frame"`,
`lms_chat_batch()` returns one typed column per top-level schema property
after the reply columns.

**Outcome:** On the openai route with `logprobs = FALSE`,
`schema_property_columns()` in `R/chat.R` reads the names and types from
the schema. `schema_property_cell()` fills each cell. The four scalar types
give atomic columns, and a pair with `"null"` gives the same type. Other
properties give list-columns. A value that does not fit gives `NA` or
`NULL`, and `output` keeps the reply. `rlm_check_property_names()` in
`R/utils-args.R` aborts on a bad or clashing name before the server probe.

**Decisions:** D-027. The plan gate kept `output`, put the columns last,
chose the abort, and took the columns from the schema.

**Review:** One pass of three lenses, 7 of 7 criteria verified. Two NEWS
claims were fixed at the gate. The reserved name `logprobs`, nullable
`anyOf` properties, and a flaky token test went to one candidate row.
