# Changelog

## rlmstudio (development version)

- Every failed REST response now aborts through one path. This affects
  [`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
  [`lms_unload()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md),
  [`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
  [`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md),
  [`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
  [`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md),
  and
  [`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md).
  All seven now report the same message text for the same response body.
  Every one of these aborts carries the condition class
  `rlmstudio_api_error`. It also carries a `status` field, which holds
  the HTTP status as an integer.
  [`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md)
  and
  [`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
  call these functions, so their failures change in the same way. The
  aborts from
  [`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md)
  and
  [`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md)
  no longer print the call that raised them. The other five already
  suppressed it.

- Some failure messages changed as a result. A JSON body whose `error`
  field is a plain string now reports that string. Before,
  [`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
  [`lms_unload()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md),
  [`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
  and
  [`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md)
  printed the whole raw body, and
  [`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
  and
  [`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md)
  printed the status. A JSON body that carries no readable message now
  reports `HTTP Status <n>`. Before, such a body gave the raw body text,
  a fragment of the `error` object, or a crash, depending on the
  function and the shape. A body that is not JSON and holds text now
  reports that text at all seven functions. Before, the three chat
  functions printed the status instead. An empty body still reports
  `HTTP Status <n>`. If
  [`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
  gets a successful response that does not report the model as loaded,
  it now reports the response body.

- Response bodies that used to crash now abort with a message. Before,
  all seven functions raised a raw R error on at least one body shape.
  An `error` field holding an empty object, an empty array, or an array
  of strings raised errors such as `argument is of length zero`. At
  [`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
  [`lms_unload()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md),
  [`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
  and
  [`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md),
  an empty response body raised `Can't retrieve empty body.`

- [`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
  now reports a failed REST response through that same path. Before, it
  raised the raw httr2 error, such as `HTTP 400 Bad Request`. It now
  aborts with the message `API List Failed:` followed by the text read
  out of the response body. The abort carries the condition class
  `rlmstudio_api_error`. It also carries a `status` field, which holds
  the HTTP status as an integer. If the status is 400 or above and the
  body carries no readable message, the abort reports `HTTP Status <n>`.
  Below status 400 it reports the body text instead. The call now aborts
  on every status other than 200. Before, only status 400 and above
  raised an error, so a status such as 201 or 302 reached the parser.

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
