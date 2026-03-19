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

test_that("lms_daemon_start handles errors", {
  mock_run_fail <- function(command, args, error_on_status) {
    list(status = 1, stdout = "", stderr = "Error starting daemon")
  }
  local_mocked_bindings(run = mock_run_fail, .package = "processx")

  expect_error(lms_daemon_start(), "Failed to start the LM Studio daemon")
})

test_that("lms_daemon_status parses multi-line output correctly", {
  mock_run_status <- function(command, args, error_on_status) {
    list(status = 0, stdout = "Status OK\n\rLoaded models: 2\n", stderr = "")
  }
  local_mocked_bindings(run = mock_run_status, .package = "processx")

  res <- lms_daemon_status()
  expect_equal(res, c("Status OK", "Loaded models: 2"))
})

test_that("lms_daemon_stop exits gracefully when managed by GUI", {
  mock_run_gui <- function(command, args, error_on_status) {
    list(status = 1, stdout = "", stderr = "part of LM Studio")
  }
  local_mocked_bindings(run = mock_run_gui, .package = "processx")

  # Expect the informational message and a return value of FALSE
  expect_message(
    res <- lms_daemon_stop(),
    "managed by the LM Studio GUI"
  )
  expect_false(res)
})

test_that("lms_daemon_stop handles force argument and generic failures", {
  mock_run_fail <- function(command, args, error_on_status) {
    list(status = 1, stdout = "", stderr = "Some unknown system error")
  }
  local_mocked_bindings(run = mock_run_fail, .package = "processx")

  expect_error(
    lms_daemon_stop(),
    "Failed to stop the LM Studio daemon"
  )
})
