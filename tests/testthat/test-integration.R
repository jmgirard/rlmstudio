test_that("End-to-end model load and chat works", {
  testthat::skip_on_cran()
  skip_if_no_lms()
  skip_if_no_server()

  # Use a tiny, fast model for integration testing
  test_model <- "qwen/qwen3-4b-2507"

  # Ensure cleanup happens even if the test fails
  on.exit(
    {
      try(lms_unload(test_model), silent = TRUE)
    },
    add = TRUE
  )

  # 1. Load the model
  load_res <- lms_load(test_model)
  expect_true(load_res)

  # 2. Check that it appears in the loaded list
  models <- list_models(loaded = TRUE)
  expect_true(test_model %in% models$key)

  # 3. Test chat generation
  chat_res <- lms_chat(
    model = test_model,
    input = "Reply with exactly the word: 'Received'."
  )

  expect_type(chat_res, "character")
  expect_true(nchar(chat_res) > 0)
})
