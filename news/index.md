# Changelog

## rlmstudio (development version)

- The server probe now honors the `host` argument. This affects
  [`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md),
  [`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
  [`lms_unload()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md),
  [`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md),
  [`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
  [`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md),
  [`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md),
  [`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
  [`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md),
  and
  [`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md).
  Before, the probe always tried `localhost:1234`, so a server on
  another hostname or port was reported as not running.
- If the server is not running,
  [`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md),
  [`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
  and
  [`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md)
  now abort instead of returning an empty data frame or `NULL`. Every
  server-down abort carries the condition class `rlmstudio_no_server`.
- [`has_lms()`](https://jmgirard.github.io/rlmstudio/reference/has_lms.md)
  now uses the same lookup as
  [`lms_path()`](https://jmgirard.github.io/rlmstudio/reference/lms_path.md):
  the `RLMSTUDIO_LMS_PATH` environment variable, then the system `PATH`,
  then common installation directories. Before, it checked only the
  `PATH`, so the two functions did not always agree.

## rlmstudio 0.2.2

CRAN release: 2026-05-05

- Fix CRAN issues

## rlmstudio 0.2.1

- Submit to CRAN

## rlmstudio 0.2.0

- Improve list–load interaction
- Handle repeat model loading elegantly
- Add first set of unit testing
- Add headless vignette
- Add pkgdown website
- Add codecov and lifecycle badges

## rlmstudio 0.1.0

- Initial development version.
