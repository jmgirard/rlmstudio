test_that("model_import aborts if the file does not exist", {
  expect_error(
    model_import(file_path = "this_file_does_not_exist.gguf"),
    regexp = "must be a valid, existing file path"
  )
})

test_that("model_import performs a dry run successfully", {
  skip_if_no_lms()
  skip_on_cran()

  dummy_model <- tempfile(fileext = ".gguf")
  file.create(dummy_model)

  expect_invisible(
    model_import(
      file_path = dummy_model,
      action = "copy",
      user_repo = "test-user/test-repo",
      dry_run = TRUE
    )
  )

  unlink(dummy_model)
})
