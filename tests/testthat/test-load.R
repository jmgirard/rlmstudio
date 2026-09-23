test_that("lms_load aborts with class rlmstudio_no_server when the server is down", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  # force = TRUE skips the list_models() branch, so the abort can only come
  # from the stop_if_no_server() call site in lms_load() itself.
  expect_error(
    lms_load("test-model", force = TRUE),
    class = "rlmstudio_no_server"
  )
})

test_that("lms_load builds body with correct integer/logical conversions", {
  local_mocked_bindings(is_server_running = function(...) TRUE)

  recorder <- local_request_sequence(list(
    mock_response(200L, '{"models": []}'),
    mock_response(200L, '{"status": "loaded"}')
  ))

  suppressMessages({
    lms_load(
      model = "test-model",
      context_length = "2048", # string that should become integer
      flash_attention = 1, # numeric that should become logical
      custom_param = "extra" # testing the dots (...) modification
    )
  })

  # Without force = TRUE this call first asks list_models() what is loaded, so
  # the load request is the second one the recorder sees.
  expect_length(recorder$requests, 2L)

  body_data <- request_target(recorder$requests[[2]])$body
  expect_equal(body_data$model, "test-model")
  expect_equal(body_data$context_length, 2048L)
  expect_true(body_data$flash_attention)
  expect_equal(body_data$custom_param, "extra")
})
