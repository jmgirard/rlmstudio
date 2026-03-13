test_that("list_models returns a formatted data frame", {
  # Mock the server check to always return TRUE for this test
  testthat::local_mocked_bindings(is_server_running = function() TRUE)

  httptest2::with_mock_dir("list_models", {
    # The first time this runs, you must have the server on.
    # It will save the HTTP response to tests/testthat/list_models/
    res <- list_models(host = "http://localhost:1234")

    expect_s3_class(res, "data.frame")
    expect_true(all(c("state", "type", "display_name", "key") %in% names(res)))
  })
})
