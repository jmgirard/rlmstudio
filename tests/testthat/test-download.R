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

test_that("print() shows a job_id with braces and does not run it", {
  status <- structure(
    list(job_id = brace_probe, status = "downloading"),
    class = "lms_download_status"
  )
  shown <- capture_shown(print(status))
  expect_null(shown$error)
  expect_match(
    shown$messages,
    paste("Download Job:", brace_probe_val),
    fixed = TRUE
  )
  expect_no_match(shown$stdout, "EVALUATED", fixed = TRUE)
})

test_that("lms_download() shows a job_id with braces and does not run it", {
  withr::local_options(rlmstudio.quiet = FALSE)
  local_mocked_bindings(is_server_running = function(...) TRUE)
  body <- jsonlite::toJSON(
    list(job_id = brace_probe, status = "downloading"),
    auto_unbox = TRUE
  )
  local_request_sequence(list(mock_response(200L, as.character(body))))
  shown <- capture_shown(job_id <- lms_download("google/gemma-3-1b"))
  expect_null(shown$error)
  expect_identical(job_id, brace_probe)
  expect_match(
    shown$messages,
    paste("Job ID:", brace_probe_val),
    fixed = TRUE
  )
  expect_no_match(shown$stdout, "EVALUATED", fixed = TRUE)
})
