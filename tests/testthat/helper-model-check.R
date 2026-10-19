# Helpers shared by the tests of the reply-model check and the model-name
# stops, in test-model-check.R and test-model-stops.R.

# A model list whose entries are given as `key = c(instance ids)`.
model_list_response <- function(...) {
  entries <- list(...)
  models <- lapply(names(entries), function(key) {
    list(
      type = "llm",
      key = key,
      loaded_instances = lapply(entries[[key]], \(id) list(id = id))
    )
  })
  mock_response(
    200L,
    as.character(jsonlite::toJSON(list(models = models), auto_unbox = TRUE))
  )
}

# Assert that `err` reports a reply from `reply_model` to a call for `asked`.
expect_mismatch <- function(err, asked, reply_model, info = NULL) {
  expect_true(inherits(err, "rlmstudio_model_mismatch"), info = info)
  expect_true(inherits(err, "rlmstudio_bad_response"), info = info)
  expect_identical(err$model, asked, info = info)
  expect_identical(err$reply_model, reply_model, info = info)
  expect_identical(err$status, 200L, info = info)
  msg <- gsub("[[:space:]]+", " ", cli::ansi_strip(conditionMessage(err)))
  expect_true(grepl(asked, msg, fixed = TRUE), info = info)
  expect_true(grepl(reply_model, msg, fixed = TRUE), info = info)
  expect_false(grepl("simplify", msg, fixed = TRUE), info = info)
}

# Log every request that reaches the real req_perform(), so a test can count
# the requests of a recorded playback.
local_request_log <- function(.env = parent.frame()) {
  log <- new.env(parent = emptyenv())
  log$urls <- character()
  real <- httr2::req_perform
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      log$urls <- c(log$urls, req$url)
      real(req, ...)
    },
    .package = "httr2",
    .env = .env
  )
  log
}

# Count the requests in `urls` that went to each endpoint: the chat routes,
# the embeddings route, and the model list of the lookup.
count_requests <- function(urls) {
  c(
    chat = sum(grepl("/v1/(chat/completions|responses)$", urls)),
    embed = sum(grepl("/v1/embeddings$", urls)),
    lookup = sum(grepl("/api/v1/models$", urls))
  )
}

# The URLs of the requests that a recorder captured.
recorder_urls <- function(recorder) {
  vapply(recorder$requests, \(req) req$url, character(1))
}
