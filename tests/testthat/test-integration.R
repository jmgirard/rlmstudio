test_that("End-to-end model load and chat works", {
  testthat::skip_on_cran()

  local_mocked_bindings(
    has_lms = function() TRUE,
    is_server_running = function() TRUE
  )

  skip_if_no_lms()
  skip_if_no_server()

  test_model <- "google/gemma-3-1b"

  # Safe teardown fallback (silences the error if it runs unmocked)
  on.exit(
    {
      try(lms_unload(test_model), silent = TRUE)
    },
    add = TRUE
  )

  httptest2::with_mock_dir("integration_e2e", {
    load_res <- lms_load(test_model)

    models <- list_models(loaded = TRUE, quiet = TRUE)

    chat_res <- lms_chat(
      model = test_model,
      input = "Reply with exactly the word: 'Received'."
    )

    # Explicitly unload inside the mock so httptest2 records it
    try(lms_unload(test_model), silent = TRUE)
  })

  expect_equal(load_res, test_model)
  expect_true(test_model %in% models$key)
  expect_type(chat_res, "character")
  expect_true(nchar(chat_res) > 0)
})
