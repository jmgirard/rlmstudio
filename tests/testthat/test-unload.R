test_that("lms_unload aborts with class rlmstudio_no_server when the server is down", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(lms_unload("test-model"), class = "rlmstudio_no_server")
})

test_that("lms_unload_all aborts with class rlmstudio_no_server when the server is down", {
  # list_models() runs its own server check, so it is mocked out here. The
  # abort can then only come from the call site in lms_unload_all() itself.
  local_mocked_bindings(
    is_server_running = function(...) FALSE,
    list_models = function(...) data.frame()
  )
  expect_error(lms_unload_all(), class = "rlmstudio_no_server")
})

test_that("lms_unload posts once to the unload path and returns the id invisibly", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(
    mock_response(200L, '{"status": "unloaded"}')
  )

  suppressMessages({
    result <- expect_invisible(lms_unload("test-model"))
  })

  expect_equal(result, "test-model")
  expect_length(recorder$requests, 1L)

  target <- request_target(recorder$requests[[1]])
  expect_equal(target$method, "POST")
  expect_equal(target$path, "/api/v1/models/unload")
})

test_that("lms_unload merges a named dots argument into the request body", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(mock_response(200L))

  suppressMessages(lms_unload("test-model", ttl = 300))

  body <- recorder$requests[[1]]$body$data
  expect_equal(body$instance_id, "test-model")
  expect_equal(body$ttl, 300)
})

test_that("lms_unload reports the error message field of a JSON body", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(
    mock_response(400L, '{"error": {"message": "nested message"}}')
  )

  expect_error(
    suppressMessages(lms_unload("test-model")),
    "API Unload Failed: nested message",
    fixed = TRUE
  )
})

test_that("lms_unload reports a JSON error object that has no message field", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(400L, '{"error": {"code": "E42"}}'))

  expect_error(
    suppressMessages(lms_unload("test-model")),
    "API Unload Failed: E42",
    fixed = TRUE
  )
})

test_that("lms_unload falls back to the body text when the JSON error is a string", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(400L, '{"error": "top level error"}'))

  # A string `error` field aborts at `err_json$error$message`, so the tryCatch
  # handler supplies the raw body rather than the field value.
  expect_error(
    suppressMessages(lms_unload("test-model")),
    'API Unload Failed: {"error": "top level error"}',
    fixed = TRUE
  )
})

test_that("lms_unload falls back to the body text when the JSON has no error field", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(400L, '{"detail": "no error field"}'))

  expect_error(
    suppressMessages(lms_unload("test-model")),
    'API Unload Failed: {"detail": "no error field"}',
    fixed = TRUE
  )
})

test_that("lms_unload falls back to the body text when the body is not JSON", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(502L, "Bad Gateway, not JSON"))

  expect_error(
    suppressMessages(lms_unload("test-model")),
    "API Unload Failed: Bad Gateway, not JSON",
    fixed = TRUE
  )
})

test_that("lms_unload names the HTTP status when the extracted message is empty", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(503L, '{"error": {"message": ""}}'))

  expect_error(
    suppressMessages(lms_unload("test-model")),
    "API Unload Failed: HTTP Status 503",
    fixed = TRUE
  )
})

test_that("lms_unload_all returns early when list_models reports nothing loaded", {
  local_mocked_bindings(
    is_server_running = function(...) TRUE,
    list_models = function(...) data.frame()
  )
  recorder <- local_request_recorder()

  expect_message(
    result <- expect_invisible(lms_unload_all()),
    "No models are currently loaded"
  )

  expect_null(result)
  expect_length(recorder$requests, 0L)
})
