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

  if (any(grepl("Server", status_lines, ignore.case = TRUE))) {
    skip("LM Studio daemon (or GUI) is already running.")
  }

  expect_invisible(daemon_up())
})

test_that("daemon_down executes safely", {
  skip_if_no_lms()
  skip_on_cran()

  status_lines <- daemon_status()

  if (any(grepl("running|active|listening|ON", status_lines, ignore.case = TRUE))) {
    skip("LM Studio daemon or GUI is already running. Skipping to avoid disruption.")
  }

  daemon_up()
  Sys.sleep(2)
  expect_invisible(daemon_down())
})

test_that("with_daemon correctly manages the lifecycle", {
  skip_if_no_lms()
  skip_on_cran()

  status_lines <- daemon_status()

  # 1. Check if GUI is managing the process (covers ON and OFF)
  is_gui <- any(grepl("part of LM Studio", status_lines, ignore.case = TRUE))

  # 2. Check if a standalone daemon is already active
  is_active <- any(grepl("\\b(running|active|listening|ON)\\b", status_lines, ignore.case = TRUE)) &&
               !any(grepl("not running|offline", status_lines, ignore.case = TRUE))

  if (is_gui || is_active) {
    skip("LM Studio engine is already managed by GUI or standalone daemon. Skipping.")
  }

  res <- with_daemon({
    2 * 3
  })

  expect_equal(res, 6)

  status_after <- daemon_status()
  expect_false(
    any(grepl("\\b(running|active|listening|ON)\\b", status_after, ignore.case = TRUE)) &&
    !any(grepl("not running|offline", status_after, ignore.case = TRUE))
  )
})

test_that("daemon_down with force = TRUE handles server shutdown safely", {
  skip_if_no_lms()
  skip_on_cran()

  status_lines <- daemon_status()
  if (any(grepl("running|active|listening|ON", status_lines, ignore.case = TRUE))) {
    skip("LM Studio daemon or GUI is already running. Skipping force teardown test.")
  }

  # Start the standalone daemon
  daemon_up()

  # Ensure the force argument runs cleanly (it will try to run server_stop() under the hood)
  # Even if no server is running, the tryCatch should prevent it from failing
  expect_invisible(daemon_down(force = TRUE))
})
