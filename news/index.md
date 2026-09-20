# Changelog

## rlmstudio (development version)

- A model name or a job id that the server cannot use now aborts before
  the request goes out. The message names the argument and the rule the
  value broke. The check covers `model` on
  [`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md),
  [`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md),
  [`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md),
  [`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md),
  [`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
  [`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
  [`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md),
  [`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
  and
  [`lms_unload()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md).
  It covers `job_id` on
  [`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md).
  Each of these must be one name, given as a single string. These all
  abort: a vector of two names, an empty character vector, `NA`, an
  empty string, and a string of whitespace only. So do a one-by-one
  matrix, `NULL`, and any value that is not a character string. Before,
  eight of these functions had no check on `model` at all. A vector of
  two names went to those as a JSON array of two. The error that came
  back named neither the argument nor the mistake.
  [`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
  was the one exception. If a model was already loaded, it raised a bare
  R error from its already-loaded test instead.

- A missing value inside a text argument now aborts. `lms_embed(input)`
  and `lms_chat_batch(inputs)` must hold at least one value and no `NA`.
  On
  [`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md),
  [`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md),
  and
  [`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
  a character `input` must hold no `NA`. A value of any other type still
  passes through to the server on those three. The structured input form
  that the OpenResponses endpoint accepts therefore still works. Two
  things stay unchecked. `lms_chat_openai(messages)` takes a list, which
  no rule here reaches. On the three chat wrappers above, a character
  `input` of length zero still goes out as an empty JSON array. Before,
  an `NA` went out as JSON `null`. The server then answered with an
  error or a count that named neither the `NA` nor its position.

- Two of these messages changed text.
  [`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md)
  and
  [`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md)
  used to say “You must provide a valid model identifier or URL.” and
  “You must provide a valid job_id.”. Those two checks also raised a
  bare R error, rather than their own message, when the argument held
  more than one value.

- A new function,
  [`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md),
  turns text into the vectors that an embedding model produces for it.
  Give it a loaded embedding model and a character vector of texts. The
  whole vector goes out in one request to the server. By default the
  return is a numeric matrix. It has one row per input text and one
  column per embedding dimension, so it goes straight to
  [`dist()`](https://rdrr.io/r/stats/dist.html) or
  [`prcomp()`](https://rdrr.io/r/stats/prcomp.html). The matrix carries
  no row or column names, so rows pair with inputs by position. The row
  at each position holds the vector that the response reported for the
  text at that position, whatever order the server answered in. With
  `simplify = FALSE` the return is the parsed response body instead. A
  `token` argument works as it does on the other functions that reach
  the REST API. The `...` argument forwards any other field to the
  request body.

- [`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
  reads the response before it builds the matrix, and aborts rather than
  returning a matrix it cannot trust. It aborts on each of these. The
  response body is not JSON at all. The response body is a plain value
  rather than an object or an array. The response carries no list of
  vectors, which is also what a body sent as a bare array reports,
  because such a body can carry no named field. The list of vectors is a
  plain value rather than a list. The list of vectors arrived as a JSON
  object rather than an array. It carries a different number of vectors
  than there were texts. A vector carries no position, or a position
  that is not a whole number. Two vectors carry the same position. A
  position falls outside the range of the texts. A vector is not a list
  of numbers. A vector is an empty list. An entry in the list of vectors
  is not an object at all. The vectors are of unequal length. These
  aborts carry the new condition class `rlmstudio_bad_response` and a
  `status` field holding the HTTP status as an integer. Every message
  but one names `simplify = FALSE`, which returns the body unchanged so
  you can read what arrived. The exception is a body that is not JSON:
  the parse runs before `simplify` is read, so that message instead
  tells you to check what is answering on the host.

- The help pages now document a third condition class.
  `rlmstudio_bad_response` has its own section on the
  `rlmstudio-conditions` page and its own alias, so
  [`?rlmstudio_bad_response`](https://jmgirard.github.io/rlmstudio/reference/rlmstudio-conditions.md)
  reaches it. The same section appears on the
  [`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
  page. The class means a response that the server did not report as a
  failure and that the package still cannot read. That is a different
  thing from `rlmstudio_api_error`.

- A new function,
  [`lms_server_ready()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_ready.md),
  reports whether a host answers as an LM Studio server you can use. It
  sends one GET request to the model list endpoint and returns `TRUE`
  only for an HTTP 200 whose body carries a list of models. An empty
  list counts, because a fresh install has nothing downloaded and its
  server still works. Every other answer returns `FALSE`: a refused
  connection, a listener that never replies, a rejected token, a failed
  status, and a body that is not a model list. The function raises
  nothing of its own for any of these, so a caller can branch on the
  value directly. A `timeout` argument sets how many seconds to wait,
  and defaults to 2. A `token` argument works as it does on the other
  functions that reach the REST API. A `token` that is not one character
  string and not `NULL` still aborts.

- The help page for the error conditions now says what the server check
  actually reads. Functions that call the REST API open a TCP connection
  to the host and port. Any process holding that port accepts the
  connection, so `rlmstudio_no_server` is not raised even though no LM
  Studio server is there. The call then fails later as an
  `rlmstudio_api_error` or as a raw parse error. The page names
  [`lms_server_ready()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_ready.md)
  as the stronger test. The same section appears on the help page of
  every exported function that can raise the condition.

- Both vignettes now ask whether the server answers before they call it.
  A host that does not answer makes them skip their REST examples.
  Before, a server that was not usable made the vignette fail to build.

- The package can now authenticate to an LM Studio server that requires
  an API token. Eleven functions take a `token` argument. They are
  [`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md),
  [`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
  [`lms_unload()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md),
  [`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md),
  [`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
  [`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md),
  [`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md),
  [`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md),
  [`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
  [`lms_chat_openai()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openai.md),
  and
  [`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md).
  Each one sends the value as a bearer token in the `Authorization`
  header of every request it makes. When `token` is not given, the
  package reads the `rlmstudio.token` option, and then the
  `RLMSTUDIO_API_TOKEN` environment variable. When none of the three
  holds a value, the request carries no `Authorization` header. A new
  help topic, `rlmstudio_token`, is the source. On the nine of these
  functions that take `...`, `token` sits after the dots. It is
  therefore matched by name alone, and no existing argument moved
  position.

- A printed request shows the `Authorization` header as `<REDACTED>`
  rather than showing the token. The package never puts the token into
  the message of a failed REST call. That message does repeat the text
  the server sent. An R backtrace also repeats your own calling line.
  Neither one is under the package’s control.

- A `token` argument that is not one character string and not `NULL` now
  aborts. Before, a value such as a vector of two strings was discarded
  without a message. The call then fell through to the option and the
  environment variable.

- A REST response with HTTP status 401 or 403 now adds a hint to the
  abort. If the request carried no token, the hint names
  `RLMSTUDIO_API_TOKEN` and the `token` argument. If the request carried
  a token, the hint says that the server rejected it. Other statuses
  gain no hint.

- The help pages now document the two error condition classes that this
  package raises. A new help topic, `rlmstudio-conditions`, is the
  source. It names the situation that raises `rlmstudio_no_server` and
  the situation that raises `rlmstudio_api_error`. It states that an
  `rlmstudio_api_error` condition carries a `status` field, which holds
  the HTTP status as an integer. It shows how to catch each class with
  [`tryCatch()`](https://rdrr.io/r/base/conditions.html). The same two
  sections now appear on the help page of every exported function that
  can raise one of these classes. The pages of
  [`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md),
  [`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md),
  and
  [`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md)
  also name the function that they reach the abort through.

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
