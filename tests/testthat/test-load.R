test_that("lms_load builds body with correct integer/logical conversions", {
  local_mocked_bindings(is_server_running = function() TRUE)

  # We capture the request object to inspect the built JSON body
  captured_req <- NULL
  mock_perform <- function(req) {
    captured_req <<- req
    # Return a fake successful response
    httr2::response(
      status_code = 200,
      body = charToRaw('{"status": "loaded"}'),
      headers = list(`Content-Type` = "application/json")
    )
  }
  local_mocked_bindings(req_perform = mock_perform, .package = "httr2")

  suppressMessages({
    lms_load(
      model = "test-model",
      context_length = "2048", # string that should become integer
      flash_attention = 1, # numeric that should become logical
      custom_param = "extra" # testing the dots (...) modification
    )
  })

  body_data <- captured_req$body$data
  expect_equal(body_data$model, "test-model")
  expect_equal(body_data$context_length, 2048L)
  expect_true(body_data$flash_attention)
  expect_equal(body_data$custom_param, "extra")
})
