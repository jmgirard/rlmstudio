test_that("list_models aborts with class rlmstudio_no_server when the server is down", {
  testthat::local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(list_models(), class = "rlmstudio_no_server")
})

test_that("list_models sends a GET request to api/v1/models", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(mock_response(200L, '{"models": []}'))

  suppressMessages(list_models())

  expect_length(recorder$requests, 1L)

  # httr2 infers the verb from the body, so a body added to this request
  # silently turns it into a POST. Assert the verb as well as the path.
  target <- request_target(recorder$requests[[1]])
  expect_equal(target$method, "GET")
  expect_equal(target$path, "/api/v1/models")
})

test_that("list_models returns a formatted data frame", {
  # Mock the server check to always return TRUE for this test
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  httptest2::with_mock_dir("list_models", {
    # The first time this runs, you must have the server on.
    # It will save the HTTP response to tests/testthat/list_models/
    res <- list_models(host = "http://localhost:1234")

    expect_s3_class(res, "data.frame")
    expect_true(all(c("state", "type", "display_name", "key") %in% names(res)))
  })
})
