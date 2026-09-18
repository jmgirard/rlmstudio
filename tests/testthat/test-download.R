test_that("lms_download aborts with class rlmstudio_no_server when the server is down", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(lms_download("google/gemma-3-1b"), class = "rlmstudio_no_server")
})

test_that("lms_download_status aborts with class rlmstudio_no_server when the server is down", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(lms_download_status("job-1"), class = "rlmstudio_no_server")
})

test_that("the server-down abort names lms_server_start", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(lms_download("google/gemma-3-1b"), "lms_server_start")
})
