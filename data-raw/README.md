# Live-run steps before a release

The tests, the recorded responses, and the vignettes reach LM Studio only in
a live run that you start. `R CMD check` and CRAN never reach it.
So before each release, do the four steps below, in this order, on a
computer with LM Studio installed. This directory does not ship with the
package.

If your server requires an API token, set `RLMSTUDIO_API_TOKEN` in each
shell or R session below.

## Models

The live tests and the recorder scripts name these models. Before you
start, download each one, for example with `lms get <model>`.

- `google/gemma-3-1b`, a chat model.
- `qwen/qwen3-4b-2507`, a chat model. Only
  `record-model-mismatch-cassette.R` uses it.
- `text-embedding-nomic-embed-text-v1.5`, an embedding model.

## 1. Start the server with the live-test models

```sh
lms server start
lms load google/gemma-3-1b -y
lms load text-embedding-nomic-embed-text-v1.5 -y
```

Load no other model. With a third model loaded,
`record-list-instances-cassette.R` in step 3 stops.

## 2. Run the tests

From the package root, run `devtools::test()`. Read the list of skipped
tests at the end of the output. Make sure that no test skipped with one of
these reasons:

- `LM Studio local server is not running.`
- `<model> is not loaded.`
- `<model> needs exactly one instance with a context length.`
- `no model is loaded.`

If a test skipped for one of them, fix the server or the models. Then run
the tests again.

## 3. Re-record the cassettes

A cassette is a directory of recorded server responses under
`tests/testthat/`. The tests read it, so they do not need LM Studio. Each
directory gets a new recording in one of two ways.

A recorder script records these directories. Run each script from the
package root with `Rscript data-raw/<script>`, in the order of the table.
The first script needs the two models of step 1 loaded, and no other model.
The schema script unloads `google/gemma-3-1b` at its end, so it runs last.

| Directory | Recorder script |
|---|---|
| `list_instances` | `record-list-instances-cassette.R` |
| `embed_live` | `record-embed-cassette.R` |
| `chat_cutoff_live` | `record-cutoff-cassette.R` |
| `mismatch_live` | `record-model-mismatch-cassette.R` |
| `thread_live` | `record-thread-cassette.R` |
| `chat_schema_live` | `record-schema-cassette.R` |

The mismatch script calls the `lms` command by name, so it must be on your
`PATH`. Read the header of each script for its other conditions.

The test records the other directories itself. For an absent directory,
httptest2 records the responses. For a present one, it reads them. So
remove the directory, and then run its test file with the server running:

| Directory | Command after you remove the directory |
|---|---|
| `chat_integration` | `devtools::test(filter = "^chat$")` |
| `integration_e2e` | `devtools::test(filter = "^integration$")` |
| `list_models` | `devtools::test(filter = "^list$")` |

One more directory that git tracks needs no new recording:

| Directory | What it holds |
|---|---|
| `fixtures` | No recorded responses. It holds example replies copied from the LM Studio docs. |

Leave it as it is. A filtered run such as `devtools::test(filter = "^list$")`
can also leave an empty `_snaps` directory. Git does not track it, and you
can delete it.

After all the recordings, run `devtools::test()` again. Read the
`git diff` of the `tests/testthat` directory. If a provenance header names a recording
date, update it.

## 4. Re-knit the vignettes

With the server running or a model loaded, `knit-vignettes.R` refuses to
start. So unload the models and stop the server first:

```sh
lms unload --all
lms server stop
Rscript data-raw/knit-vignettes.R
```

The script fails a vignette on a chunk error, or on a chunk warning that
the chunk does not mark with `expect_warning = TRUE`. Read the `git diff`
of `vignettes/*.Rmd`, and make sure that the prose still matches the new
output. If you edit a `.Rmd.orig` source, knit it again.
`tests/testthat/test-vignette-knit.R` fails for each source that changed
after its knit.
