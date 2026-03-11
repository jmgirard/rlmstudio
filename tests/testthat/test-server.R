test_that("server_status warns when multiple logging flags are used", {
  skip_if_no_lms()
  skip_on_cran()

  expect_warning(
    server_status(verbose = TRUE, quiet = TRUE),
    regexp = "Only one logging control flag"
  )
})

test_that("server_start and server_stop execute and return invisibly", {
  skip_if_no_lms()
  skip_on_cran()

  expect_invisible(server_start(port = 8888, cors = TRUE))

  expect_invisible(server_stop())
})

test_that("server_start aborts on failure", {
  skip_if_no_lms()
  skip_on_cran()

  server_start(port = 8888)

  expect_error(
    server_start(port = 8888),
    regexp = "Failed to start"
  )

  server_stop()
})
