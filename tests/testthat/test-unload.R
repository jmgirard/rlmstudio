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
