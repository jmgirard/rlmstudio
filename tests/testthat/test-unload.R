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
