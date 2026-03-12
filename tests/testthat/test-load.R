test_that("model_load executes safely using estimate_only and parallel", {
  skip_if_no_lms()
  skip_on_cran()

  local_models <- model_ls()

  if (!any(grepl("llama-3.1-8b", local_models, ignore.case = TRUE))) {
    skip("Target model 'llama-3.1-8b' is not installed locally. Skipping load test.")
  }

  expect_invisible(
    model_load(
      model = "llama-3.1-8b",
      parallel = 2,
      estimate_only = TRUE
    )
  )
})

test_that("model_unload executes when unloading all models", {
  skip_if_no_lms()
  skip_on_cran()

  expect_invisible(model_unload(all = TRUE))
})
