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

test_that("lms_score_expected() sums the candidates that give the same label", {
  # "3", " 3", and "3.0" all give the label 3, with "4" between them and a
  # newline outside the scale.
  lp_df <- data.frame(
    step_token = "3",
    step_logprob = log(0.3),
    candidate_token = c("3", "4", " 3", "\n", "3.0"),
    candidate_logprob = log(c(0.3, 0.2, 0.1, 0.1, 0.05)),
    step = 1L,
    stringsAsFactors = FALSE
  )

  res <- lms_score_expected(lp_df, scale = 1:5)

  # Label 3: 0.3 + 0.1 + 0.05 = 0.45. Label 4: 0.2. Total 0.65.
  # Rescaled: 0.45 / 0.65 = 9/13 and 0.2 / 0.65 = 4/13, in the order in
  # which each label first appears.
  expect_identical(res$probabilities$label, c(3, 4))
  expect_equal(res$probabilities$prob, c(9 / 13, 4 / 13))
  # Expected value: 3 * 9/13 + 4 * 4/13 = 43/13 = 3.307692. Summing the rows
  # does not change it.
  expect_equal(res$expected_value, 43 / 13)
  # Weighted SD: sqrt(9/13 * (3 - 43/13)^2 + 4/13 * (4 - 43/13)^2)
  #   = sqrt(9/13 * 16/169 + 4/13 * 81/169) = sqrt(36/169) = 6/13.
  expect_equal(res$weighted_sd, 6 / 13)
  # Entropy in bits over the two summed labels:
  #   -(9/13 * log2(9/13) + 4/13 * log2(4/13)) = 0.3672794 + 0.5232122
  #   = 0.8904916. Over the four unsummed rows it would be 1.738149.
  expect_equal(res$entropy, 0.8904916, tolerance = 1e-6)
})

# A logprobs frame from columns. `step` is left out when it is NULL.
score_frame <- function(step_token, candidate_token, prob, step = NULL) {
  lp_df <- data.frame(
    step_token = step_token,
    step_logprob = -0.5,
    candidate_token = candidate_token,
    candidate_logprob = log(prob),
    stringsAsFactors = FALSE
  )
  if (!is.null(step)) {
    lp_df$step <- step
  }
  lp_df
}

# The score of a first step that holds "3" at 0.6 and "4" at 0.2, the case
# that every frame below is built to read. Rescaled to sum to 1, the
# probabilities are 0.6 / 0.8 = 0.75 and 0.2 / 0.8 = 0.25.
# Expected value: 3 * 0.75 + 4 * 0.25 = 3.25.
# Weighted SD: sqrt(0.75 * (3 - 3.25)^2 + 0.25 * (4 - 3.25)^2)
#   = sqrt(0.75 * 0.0625 + 0.25 * 0.5625) = sqrt(0.1875) = 0.4330127.
# Entropy in bits: -(0.75 * log2(0.75) + 0.25 * log2(0.25))
#   = 0.75 * 0.4150375 + 0.25 * 2 = 0.8112781.
expect_first_step_score <- function(res, info = NULL) {
  expect_identical(res$probabilities$label, c(3, 4), info = info)
  expect_equal(res$probabilities$prob, c(0.75, 0.25), info = info)
  expect_equal(res$expected_value, 3.25, info = info)
  expect_equal(res$weighted_sd, 0.4330127, tolerance = 1e-6, info = info)
  expect_equal(res$entropy, 0.8112781, tolerance = 1e-6, info = info)
}

test_that("lms_score_expected() reads the rows of the first step by the step column", {
  # Each later step with the token "3" holds a "2" or a "5", which would move
  # the score if it counted. The newline step holds no number.
  frames <- list(
    # Steps 1 and 3 share the step token "3", with a newline step between.
    "steps 1 and 3 share a token" = score_frame(
      step_token = c("3", "3", "\n", "3", "3"),
      candidate_token = c("3", "4", "\n", "2", "5"),
      prob = c(0.6, 0.2, 0.9, 0.3, 0.1),
      step = c(1L, 1L, 2L, 3L, 3L)
    ),
    # Steps 1 and 2 are adjacent and share the step token "3".
    "steps 1 and 2 share a token" = score_frame(
      step_token = c("3", "3", "3", "3"),
      candidate_token = c("3", "4", "2", "5"),
      prob = c(0.6, 0.2, 0.3, 0.1),
      step = c(1L, 1L, 2L, 2L)
    ),
    # A row of step 1 comes after a row of step 2.
    "a step 1 row after a step 2 row" = score_frame(
      step_token = c("3", "3", "3"),
      candidate_token = c("3", "2", "4"),
      prob = c(0.6, 0.3, 0.2),
      step = c(1L, 2L, 1L)
    )
  )
  for (case in names(frames)) {
    lp_df <- frames[[case]]
    res <- lms_score_expected(lp_df, scale = 1:5)
    expect_first_step_score(res, info = case)
    # The rows of step 1 alone give the same result.
    expect_identical(
      res,
      lms_score_expected(lp_df[lp_df$step == 1L, ], scale = 1:5),
      info = case
    )
  }
})

test_that("lms_score_expected() reads the first run of a step token without a step column", {
  # The step tokens run "3", "\n", "3". The last "3" rows hold a "2" and a
  # "5" and do not count.
  lp_df <- score_frame(
    step_token = c("3", "3", "\n", "3", "3"),
    candidate_token = c("3", "4", "\n", "2", "5"),
    prob = c(0.6, 0.2, 0.9, 0.3, 0.1)
  )
  expect_first_step_score(lms_score_expected(lp_df, scale = 1:5))

  # A first step token of NA: the run is the leading NA rows. The "3" row
  # and the NA row after it do not count.
  lp_df <- score_frame(
    step_token = c(NA, NA, "3", NA),
    candidate_token = c("3", "4", "2", "5"),
    prob = c(0.6, 0.2, 0.3, 0.1)
  )
  expect_first_step_score(lms_score_expected(lp_df, scale = 1:5))
})

test_that("lms_score_expected() reads the first run of a step token when the first step is NA", {
  # The step column is NA in the first row, so the run of the step token
  # "3" in rows 1 and 2 counts, and the step column is not read.
  lp_df <- score_frame(
    step_token = c("3", "3", "\n", "3"),
    candidate_token = c("3", "4", "\n", "2"),
    prob = c(0.6, 0.2, 0.9, 0.3),
    step = c(NA, 1L, 2L, 3L)
  )
  res <- lms_score_expected(lp_df, scale = 1:5)
  expect_first_step_score(res)
  # The same frame with no step column gives the same result.
  expect_identical(
    res,
    lms_score_expected(lp_df[setdiff(names(lp_df), "step")], scale = 1:5)
  )
})

test_that("lms_score_expected() gives an entropy of 0 for one label", {
  # "3" and " 3" give the one label 3, with probability 1 after the sum.
  # Entropy in bits: -(1 * log2 1) = 0.
  lp_df <- data.frame(
    step_token = c("3", "3"),
    step_logprob = c(-0.2, -0.2),
    candidate_token = c("3", " 3"),
    candidate_logprob = log(c(0.6, 0.3)),
    stringsAsFactors = FALSE
  )
  res <- lms_score_expected(lp_df, scale = 1:5)
  expect_identical(res$probabilities$label, 3)
  expect_identical(res$entropy, 0)
})

test_that("lms_score_expected() aborts on a frame with no step_token and no step column", {
  # With neither column, no row is read as the first step, so no candidate
  # is in the scale.
  lp_df <- data.frame(
    candidate_token = c("3", "4"),
    candidate_logprob = log(c(0.6, 0.3)),
    stringsAsFactors = FALSE
  )
  expect_error(
    lms_score_expected(lp_df, scale = 1:5),
    "No tokens in the top candidates matched the provided scale."
  )
})
