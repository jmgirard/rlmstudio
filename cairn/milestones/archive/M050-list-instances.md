# M050: A table of loaded model instances

**Status:** done (2026-09-29, PR #50 https://github.com/jmgirard/rlmstudio/pull/50)

**Goal:** A new function `list_instances()` returns one row per loaded model
instance, with the load configuration of each instance in columns.

**Outcome:** `list_instances(type, quiet, host, token)` in `R/list.R` reads
`/api/v1/models` through `request_model_list()`. It flattens
`loaded_instances`. The columns are `id`, `key`, `type`, and `display_name`.
`config_column()` adds one column per `config` field, with a `config.` prefix
on a clash. The empty result is a zero-row frame with the four columns.
`instance_list_fault()` rejects a non-string `display_name` and a non-object
`config`, and `list_models()` and `lms_server_ready()` do not. Help, pkgdown,
NEWS, a recorded reply, and a generator in `data-raw/` ship with it.

**Decisions:** none cross-cutting. The plan gate chose a new export over a
flag on `list_models()`, and the REST list over `lms ps --json`.

**Review:** Two passes of three lenses. Pass 1 fixed six findings and sent
AC4 back for an amendment: an absent `config` gives `NULL` in a list-column.
Pass 2 found no criterion failing. It fixed a help rewrap, a body-parse test
entry, and a test that `list_models()` accepts the two rejected bodies. The
`lms ps` fields, argument guards, and extra tests went to candidate rows.
