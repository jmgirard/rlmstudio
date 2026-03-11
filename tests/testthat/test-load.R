test_that("model_unload executes when unloading all models", {
  skip_if_no_lms()
  skip_on_cran()

  expect_invisible(model_unload(all = TRUE))
})
