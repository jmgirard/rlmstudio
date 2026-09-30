# rlmstudio: Access and Control LM Studio

Run local Large Language Models (LLMs) over many texts from 'R' without
sending data to a third party. A community-maintained wrapper for the
'LM Studio' command line interface and API that provides functions to
manage the local daemon and server, download and load models, and score,
label, or generate text at scale.

## Options

- `rlmstudio.quiet`: A logical value. If `TRUE`, suppresses
  informational console messages and progress bars across the package.
  Defaults to `FALSE`. The `quiet` argument of
  [`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md),
  [`list_instances()`](https://jmgirard.github.io/rlmstudio/reference/list_instances.md),
  [`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md),
  and
  [`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
  defaults to `NULL`, which follows this option. `quiet = TRUE` hides
  the messages of that function or starts no progress bar, and
  `quiet = FALSE` prints the messages or starts the bar, also when this
  option is `TRUE`. Warnings show either way. The option does not change
  the `quiet` argument of
  [`lms_server_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_status.md),
  which passes `--quiet` to the `lms` CLI.

## See also

Useful links:

- <https://jmgirard.github.io/rlmstudio/>

- <https://github.com/jmgirard/rlmstudio>

- Report bugs at <https://github.com/jmgirard/rlmstudio/issues>

## Author

**Maintainer**: Jeffrey Girard <me@jmgirard.com>
([ORCID](https://orcid.org/0000-0002-7359-3746)) \[copyright holder\]

Authors:

- Jeffrey Girard <me@jmgirard.com>
  ([ORCID](https://orcid.org/0000-0002-7359-3746)) \[copyright holder\]
