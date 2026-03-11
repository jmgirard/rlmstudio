test_that("runtime_get and runtime_update exit cleanly on invalid inputs", {
  skip_if_no_lms()
  skip_on_cran()
  skip_on_ci()

  if (!interactive()) {
    skip("This test requires an interactive R session.")
  }

  fake_runtime <- "invalid-runtime-xyz987"

  expect_invisible(runtime_get(fake_runtime))
  expect_invisible(runtime_update(fake_runtime))
})

test_that("runtime_select and runtime_remove abort on invalid inputs", {
  skip_if_no_lms()
  skip_on_cran()
  skip_on_ci()

  if (!interactive()) {
    skip("This test requires an interactive R session.")
  }

  fake_runtime <- "invalid-runtime-xyz987"

  expect_error(
    runtime_select(fake_runtime),
    regexp = "Failed to select runtime"
  )

  expect_error(
    runtime_remove(fake_runtime),
    regexp = "Failed to remove runtime"
  )
})
