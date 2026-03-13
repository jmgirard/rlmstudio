test_that("lms_daemon_start handles successful execution", {
  mock_run <- function(command, args, error_on_status) {
    list(status = 0, stdout = "Success", stderr = "")
  }

  testthat::local_mocked_bindings(run = mock_run, .package = "processx")

  # Suppress the cli alert for cleaner test output
  suppressMessages({
    res <- lms_daemon_start()
  })

  expect_equal(res, 0)
})
