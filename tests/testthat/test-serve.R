test_that("build_args_server_start constructs correct arguments", {
  expect_equal(build_args_server_start(), c("server", "start"))
  expect_equal(
    build_args_server_start(port = 3000, cors = TRUE),
    c("server", "start", "--port", "3000", "--cors")
  )
})

test_that("build_args_server_status handles logging flags", {
  expect_equal(
    build_args_server_status(json = TRUE, quiet = TRUE),
    c("server", "status", "--json", "--quiet")
  )
})

test_that("lms_server_start handles success and failure", {
  mock_run_success <- function(command, args, error_on_status) list(status = 0)
  local_mocked_bindings(run = mock_run_success, .package = "processx")

  suppressMessages({
    expect_equal(lms_server_start(port = 8080), 0)
  })

  mock_run_fail <- function(command, args, error_on_status) list(status = 1)
  local_mocked_bindings(run = mock_run_fail, .package = "processx")

  expect_error(lms_server_start(), "Failed to start the LM Studio server")
})

test_that("lms_server_status warns on multiple logging flags", {
  mock_run <- function(command, args, error_on_status) {
    list(status = 0, stdout = "ok", stderr = "")
  }
  local_mocked_bindings(run = mock_run, .package = "processx")

  expect_warning(
    lms_server_status(verbose = TRUE, quiet = TRUE),
    "Only one logging control flag can be used at a time"
  )
})
