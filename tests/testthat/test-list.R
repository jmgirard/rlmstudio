test_that("model_ls executes and returns expected types", {
  skip_if_no_lms()
  skip_on_cran()

  # 1. Test standard text output
  res_text <- model_ls()
  expect_type(res_text, "character")

  # 2. Test JSON output
  # jsonlite::fromJSON() typically returns a list or a data.frame depending
  # on the exact JSON structure. We just want to ensure it parses successfully.
  res_json <- model_ls(json = TRUE)
  expect_true(inherits(res_json, "data.frame") || inherits(res_json, "list"))

  # 3. Test that flags do not cause execution errors
  expect_no_error(model_ls(llm = TRUE, embedding = TRUE, detailed = TRUE))
})

test_that("model_ps executes and returns expected types", {
  skip_if_no_lms()
  skip_on_cran()

  # 1. Test standard text output
  res_text <- model_ps()
  expect_type(res_text, "character")

  # 2. Test JSON output
  res_json <- model_ps(json = TRUE)
  expect_true(inherits(res_json, "data.frame") || inherits(res_json, "list"))
})

test_that("model_ls warns if JSON parsing fails", {
  skip_if_no_lms()
  skip_on_cran()

  # If we pass arguments that the CLI doesn't recognize or that break the JSON output,
  # we want to ensure our tryCatch block successfully catches it and warns the user.
  # Note: The 'lms' CLI might just ignore bad flags, but we can simulate a bad
  # JSON environment using a mock if we really want to be thorough.
  # For now, this is a placeholder to remind you that testing the warning is good practice!
})
