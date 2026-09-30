# Extracted from test-chat-batch.R:1026

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
run_unreadable_batch <- function(ok, body, format, api_type, logprobs = FALSE) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(ok, mock_response(200L, body)))
  args <- list(
    "a-model",
    c("first", "second"),
    format = format,
    quiet = TRUE,
    api_type = api_type
  )
  if (logprobs) {
    args$logprobs <- TRUE
  }
  warnings <- testthat::capture_warnings(out <- do.call(lms_chat_batch, args))
  list(out = out, warnings = warnings)
}
stats_columns <- c(
  "input_tokens",
  "total_output_tokens",
  "reasoning_output_tokens",
  "tokens_per_second",
  "time_to_first_token_seconds",
  "model_load_time_seconds"
)
reply_columns <- c("response_id", stats_columns)
run_stats_batch <- function(
  responses,
  inputs = paste("input", seq_along(responses)),
  api_type = "native",
  logprobs = FALSE,
  capture = TRUE,
  ...
) {
  responses <- lapply(responses, function(r) {
    if (is.character(r)) mock_response(200L, r) else r
  })
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(responses)
  args <- list(
    "a-model",
    inputs,
    format = "data.frame",
    quiet = TRUE,
    api_type = api_type,
    ...
  )
  if (logprobs) {
    args$logprobs <- TRUE
  }
  if (!capture) {
    return(list(out = do.call(lms_chat_batch, args)))
  }
  warnings <- testthat::capture_warnings(out <- do.call(lms_chat_batch, args))
  list(out = out, warnings = warnings)
}
expect_reply_column_types <- function(df, info = NULL) {
  expect_type(df$response_id, "character")
  for (col in stats_columns) {
    expect_identical(typeof(df[[col]]), "double", info = paste(info, col))
  }
}
bad_values <- function(other_scalar, inner) {
  list(
    absent = NULL,
    null = "null",
    `the other scalar type` = other_scalar,
    boolean = "true",
    array = json_array(inner),
    object = json_object(a = inner)
  )
}
failing_native <- list(
  rlmstudio_api_error = mock_response(400L, '{"error": "bad request"}'),
  rlmstudio_bad_response = mock_response(
    200L,
    json_object(
      output = json_array(),
      stats = native_stats(),
      response_id = quoted("resp_bad")
    )
  )
)

# test -------------------------------------------------------------------------
testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
local_request_sequence(list(
    mock_response(200L, native_reply("x")),
    failing_native$rlmstudio_api_error,
    failing_native$rlmstudio_bad_response
  ))
expect_warning(
    out <- lms_chat_batch(
      "a-model",
      c("a", "b", "c"),
      format = "list",
      quiet = TRUE,
      api_type = "native"
    ),
    "2 inputs failed"
  )
expect_identical(out[[1]], "x")
