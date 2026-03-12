test_that("daemon_status executes and returns expected types", {
  skip_if_no_lms()
  skip_on_cran()

  res_text <- daemon_status()
  expect_type(res_text, "character")
  expect_true(length(res_text) > 0)
})

test_that("daemon_up executes and returns invisibly", {
  skip_if_no_lms()
  skip_on_cran()

  status_lines <- daemon_status()

  if (any(grepl("running|active|listening", status_lines, ignore.case = TRUE))) {
    skip("LM Studio daemon (or GUI) is already running.")
  }

  expect_invisible(daemon_up())
})

test_that("daemon_down executes safely", {
  skip_if_no_lms()
  skip_on_cran()

  status_lines <- daemon_status()

  if (any(grepl("running|active|listening", status_lines, ignore.case = TRUE))) {
    skip("LM Studio daemon or GUI is already running. Skipping to avoid disruption.")
  }

  daemon_up()

  expect_invisible(daemon_down())
})

test_that("with_daemon correctly manages the lifecycle", {
  skip_if_no_lms()
  skip_on_cran()

  status_lines <- daemon_status()
  if (any(grepl("running|active|listening", status_lines, ignore.case = TRUE))) {
    skip("LM Studio daemon or GUI is already running. Skipping lifecycle test.")
  }

  res <- with_daemon({
    2 * 3
  })

  expect_equal(res, 6)

  status_lines_after <- daemon_status()
  expect_false(
    any(grepl("running|active|listening", status_lines_after, ignore.case = TRUE))
  )
})
