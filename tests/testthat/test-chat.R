test_that("Full Integration: Download, Load, and Rate", {
  skip_if_no_lms()
  skip_if_no_server()

  # 1. Setup: Ensure the specific model is available and loaded
  target_model <- "google/gemma-3-4b" # Using a smaller variant for faster tests

  # Download if missing (assuming lms_download handles 'already exists' gracefully)
  lms_download(target_model)

  # Load the model
  lms_load(target_model, flash_attention = TRUE)

  # Ensure cleanup: unload the model when the test finishes (success or failure)
  on.exit(lms_unload(target_model), add = TRUE)

  # 2. Test Data
  reviews <- c(
    "The food was absolutely incredible!",
    "Terrible service, I will never go back."
  )
  sys_prompt <- "Rate on a scale of 1 to 5. Respond with ONLY the integer."

  # 3. Execution
  results_df <- lms_chat_batch(
    model = target_model,
    inputs = reviews,
    system_prompt = sys_prompt,
    format = "data.frame",
    api_type = "openresponses",
    logprobs = TRUE,
    top_logprobs = 5,
    temperature = 1.0,
    quiet = TRUE
  )

  # 4. Assertions
  expect_s3_class(results_df, "data.frame")
  expect_true("logprobs" %in% names(results_df))
  expect_s3_class(results_df$logprobs[[1]], "data.frame")

  # Math check
  results_df$expected_rating <- sapply(results_df$logprobs, function(lp_df) {
    if (is.null(lp_df)) {
      return(NA_real_)
    }

    # Isolate first generation step
    candidates <- lp_df[lp_df$step_token == lp_df$step_token[1], ]

    # Convert and filter
    nums <- suppressWarnings(as.numeric(candidates$candidate_token))
    valid <- !is.na(nums) & nums %in% 1:5

    if (!any(valid)) {
      return(NA_real_)
    }

    vals <- nums[valid]
    probs <- exp(candidates$candidate_logprob[valid])
    probs <- probs / sum(probs)

    sum(vals * probs)
  })

  expect_true(all(
    results_df$expected_rating >= 1 & results_df$expected_rating <= 5
  ))
})

test_that("lms_chat routes correctly to openresponses and creates S3 class", {
  local_mocked_bindings(is_server_running = function() TRUE)

  fake_body <- list(
    output = list(list(
      content = list(list(
        text = "5",
        logprobs = list(
          list(
            token = "5",
            logprob = 0,
            top_logprobs = list(list(token = "5", logprob = 0))
          )
        )
      ))
    ))
  )

  local_mocked_bindings(
    req_perform = function(req, ...) {
      httr2::response(
        status_code = 200,
        headers = list("Content-Type" = "application/json"),
        body = charToRaw(jsonlite::toJSON(fake_body, auto_unbox = TRUE))
      )
    },
    .package = "httr2"
  )

  res <- lms_chat(
    model = "test-model",
    input = "test input",
    api_type = "openresponses",
    logprobs = TRUE
  )

  expect_s3_class(res, "lms_chat_result")
  expect_equal(res$text, "5")
})
