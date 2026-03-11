test_that("read_log_stream aborts if input is not a processx object", {
  bad_input <- "not_a_process"

  expect_error(
    read_log_stream(process = bad_input),
    regexp = "must be a .*processx.* object"
  )
})

test_that("log_stream creates a background process", {
  skip_if_no_lms()
  skip_on_cran()

  stream <- log_stream(source = "server", json = TRUE)

  expect_s3_class(stream, "process")

  expect_true(stream$is_alive())

  stream$kill()
})
