test_that("lms_score_expected calculates correct values for certain outcomes", {
  # Mock: Model is 100% certain the answer is '5'
  # log(1) = 0
  lp_df <- data.frame(
    step_token = c("5", "5"),
    step_logprob = c(0, 0),
    candidate_token = c("5", "4"),
    candidate_logprob = c(0, -20), # -20 is effectively 0 probability
    stringsAsFactors = FALSE
  )

  res <- lms_score_expected(lp_df, scale = 1:5)

  # Expected Value should be 5
  expect_equal(res$expected_value, 5)
  # Weighted SD should be near 0
  expect_lt(res$weighted_sd, 0.01)
  # Entropy should be near 0
  expect_lt(res$entropy, 0.01)
})

test_that("lms_score_expected handles split decisions (bi-modal)", {
  # Mock: Model is split exactly 50/50 between 1 and 5
  # log(0.5) = -0.6931472
  lp_val <- log(0.5)
  lp_df <- data.frame(
    step_token = "1",
    step_logprob = lp_val,
    candidate_token = c("1", "5"),
    candidate_logprob = c(lp_val, lp_val),
    stringsAsFactors = FALSE
  )

  res <- lms_score_expected(lp_df, scale = 1:5)

  # EV should be (1*0.5 + 5*0.5) = 3
  expect_equal(res$expected_value, 3)
  # Entropy should be exactly 1 bit for two equal options
  expect_equal(res$entropy, 1)
  # SD should be 2: sqrt(0.5*(1-3)^2 + 0.5*(5-3)^2) = sqrt(2+2) = 2
  expect_equal(res$weighted_sd, 2)
})

test_that("lms_score_expected filters non-scale tokens", {
  # Mock: Top candidates include a newline or text
  lp_df <- data.frame(
    step_token = "3",
    step_logprob = 0,
    candidate_token = c("3", "\n", "foo"),
    candidate_logprob = c(0, -1, -2),
    stringsAsFactors = FALSE
  )

  # This should pass without error, only using the '3'
  res <- lms_score_expected(lp_df, scale = 1:5)
  expect_equal(res$expected_value, 3)
  expect_equal(nrow(res$probabilities), 1)
})

test_that("lms_score_expected aborts on no valid tokens", {
  lp_df <- data.frame(
    step_token = "A",
    step_logprob = 0,
    candidate_token = c("A", "B"),
    candidate_logprob = c(0, -1),
    stringsAsFactors = FALSE
  )

  expect_error(
    lms_score_expected(lp_df, scale = 1:5),
    "No tokens in the top candidates"
  )
})
