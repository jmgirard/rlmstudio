test_that("model_get aborts on invalid model name without hanging", {
  skip_if_no_lms()
  skip_on_cran()
  skip_on_ci()

  if (!interactive()) {
    skip("This test requires an interactive R session.")
  }

  expect_error(
    model_get(model_name = "this-model-definitely-does-not-exist-12345"),
    regexp = "Model download failed"
  )
})
