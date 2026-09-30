# Extracted from test-chat-batch.R:366

# prequel ----------------------------------------------------------------------
batch_inputs <- c("first", "second", "third")
failure_classes <- c("rlmstudio_api_error", "rlmstudio_bad_response")
usage_columns <- c(
  "response_id",
  "input_tokens",
  "total_output_tokens",
  "reasoning_output_tokens"
)
openai_ok <- function(i, schema = FALSE) {
  content <- if (schema) sprintf('{"score": %d}', i) else sprintf("reply %d", i)
  mock_response(200L, completion_body(quoted(content)))
}
openresponses_ok <- function(i, logprobs = FALSE) {
  lp <- if (logprobs) sprintf("[%s]", logprob_step("r")) else NULL
  mock_response(
    200L,
    output_body(responses_message(output_text(quoted(sprintf("reply %d", i)), lp)))
  )
}
fail_response <- function(cls, parsed) {
  switch(
    cls,
    rlmstudio_api_error = mock_response(400L, '{"error": "bad request"}'),
    rlmstudio_bad_response = if (parsed) {
      mock_response(200L, completion_body(quoted("not json")))
    } else {
      mock_response(200L, '{"id": "chatcmpl-1"}')
    }
  )
}
run_failing_batch <- function(
  fail_at,
  cls,
  format,
  schema = FALSE,
  simplify = TRUE,
  logprobs = FALSE,
  api_type = "openai",
  quiet = TRUE,
  ok = function(i) openai_ok(i, schema)
) {
  parsed <- schema && simplify && !logprobs
  responses <- lapply(seq_along(batch_inputs), ok)
  responses[fail_at] <- lapply(cls, fail_response, parsed = parsed)

  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(responses)
  args <- list(
    "a-model",
    batch_inputs,
    format = format,
    simplify = simplify,
    quiet = quiet,
    api_type = api_type
  )
  if (schema) {
    args$schema <- score_schema
  }
  if (logprobs) {
    args$logprobs <- TRUE
  }
  warnings <- testthat::capture_warnings(
    out <- do.call(lms_chat_batch, args)
  )
  list(out = out, warnings = warnings, requests = length(recorder$requests))
}
expect_failed_slot <- function(x, cls, info = NULL) {
  expect_s3_class(x, cls)
  expect_null(x$trace, info = info)
  if (cls == "rlmstudio_api_error") {
    expect_identical(x$status, 400L, info = info)
  }
}
run_lost_server_batch <- function(k, responses, format = "list") {
  probes <- 0L
  testthat::local_mocked_bindings(is_server_running = function(...) {
    probes <<- probes + 1L
    probes <= k
  })
  recorder <- local_request_sequence(responses)
  cnd <- expect_error(
    lms_chat_batch("a-model", batch_inputs, format = format, quiet = TRUE, api_type = "openai"),
    class = "rlmstudio_no_server"
  )
  list(cnd = cnd, probes = probes, requests = length(recorder$requests))
}
stop_statuses <- c(401L, 403L, 404L)
status_response <- function(status) {
  mock_response(status, '{"error": {"message": "refused"}}')
}
run_stopping_batch <- function(
  stop_at,
  status,
  format = "list",
  fail_at = integer(),
  api_type = "openai",
  ok = openai_ok,
  inputs = batch_inputs
) {
  responses <- lapply(seq_along(inputs), ok)
  responses[fail_at] <- list(fail_response("rlmstudio_api_error", parsed = FALSE))
  responses[[stop_at]] <- status_response(status)

  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(responses)
  warnings <- testthat::capture_warnings(
    cnd <- tryCatch(
      lms_chat_batch(
        "a-model",
        inputs,
        format = format,
        quiet = TRUE,
        api_type = api_type
      ),
      rlmstudio_api_error = identity
    )
  )
  list(cnd = cnd, warnings = warnings, requests = length(recorder$requests))
}

# test -------------------------------------------------------------------------
routes <- list(
    native = function(i) mock_response(200L, native_reply(sprintf("reply %d", i))),
    openresponses = openresponses_ok
  )
for (api_type in names(routes)) {
    res <- run_stopping_batch(2L, 401L, api_type = api_type, ok = routes[[api_type]])
    expect_true(inherits(res$cnd, "rlmstudio_api_error"), info = api_type)
    expect_identical(res$cnd$status, 401L, info = api_type)
    expect_identical(res$warnings, character(), info = api_type)
    expect_identical(res$requests, 2L, info = api_type)
    expect_identical(res$cnd$results, list("reply 1", NULL, NULL), info = api_type)
  }
