test_that("lms_unload aborts with class rlmstudio_no_server when the server is down", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(lms_unload("test-model"), class = "rlmstudio_no_server")
})

test_that("lms_unload_all aborts with class rlmstudio_no_server when the server is down", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(lms_unload_all(), class = "rlmstudio_no_server")
})
