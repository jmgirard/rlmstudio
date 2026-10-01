#' Calculate Expected Scores and Uncertainty from Logprobs
#'
#' Takes a logprobs dataframe (from an \code{lms_chat_result}) and calculates
#' the weighted average score, normalized probabilities, and uncertainty
#' metrics.
#'
#' @param lp_df A dataframe of logprobs (e.g., \code{x$logprobs}).
#' @param scale Numeric vector. The valid labels (e.g., \code{1:5}).
#'
#' @return A named list containing three numeric elements
#'   (\code{expected_value}, \code{weighted_sd}, \code{entropy}) and a
#'   \code{data.frame} named \code{probabilities} with columns \code{label} and
#'   \code{prob}. Returns \code{NULL} if the input dataframe is empty or
#'   invalid.
#'
#' @export
#'
#' @examples
#' # Create a sample logprobs dataframe representing a model's generation step
#' mock_logprobs <- data.frame(
#'   step_token = rep("4", 3),
#'   step_logprob = rep(0, 3),
#'   candidate_token = c("4", "5", "3"),
#'   candidate_logprob = c(-0.105, -2.302, -3.506),
#'   stringsAsFactors = FALSE
#' )
#'
#' # Calculate the expected score and uncertainty metrics
#' lms_score_expected(mock_logprobs, scale = 1:5)
lms_score_expected <- function(lp_df, scale = 1:5) {
  if (is.null(lp_df) || nrow(lp_df) == 0) {
    return(NULL)
  }

  # 1. Isolate the first decision step (where the rating happens)
  # We assume the user followed instructions and the rating is the first token
  candidates <- lp_df[first_step_rows(lp_df), ]

  # 2. Extract and clean tokens
  # Convert tokens to numbers; non-numeric (like \n) become NA
  nums <- suppressWarnings(as.numeric(candidates$candidate_token))
  valid_idx <- !is.na(nums) & (nums %in% scale)

  if (!any(valid_idx)) {
    cli::cli_abort(
      "No tokens in the top candidates matched the provided scale."
    )
  }

  vals <- nums[valid_idx]
  # Convert logprobs to raw probabilities
  probs <- exp(candidates$candidate_logprob[valid_idx])
  # Normalize so they sum to 1 (re-distributing mass from ignored tokens)
  probs <- probs / sum(probs)

  # 3. Calculations
  # Expected Value: Sum(value * prob)
  ev <- sum(vals * probs)

  # Weighted Variance: Sum(prob * (value - EV)^2)
  var_w <- sum(probs * (vals - ev)^2)
  sd_w <- sqrt(var_w)

  # Shannon Entropy: -Sum(p * log2(p))
  # Measures "surprise" or "confusion" in bits
  entropy <- -sum(probs * log2(probs + 1e-9)) # small epsilon to avoid log(0)

  # 4. Results
  list(
    expected_value = ev,
    weighted_sd = sd_w,
    entropy = entropy,
    probabilities = data.frame(
      label = vals,
      prob = probs,
      stringsAsFactors = FALSE
    )
  )
}

#' The rows of the first step of a logprobs frame
#'
#' With a `step` column whose first value is not `NA`, the rows whose `step`
#' equals that value, wherever they sit. Otherwise the first run of
#' consecutive rows whose `step_token` is identical to that of the first row,
#' `NA` included, so two adjacent steps with the same token read as one.
#'
#' @param lp_df A logprobs data frame with at least one row.
#' @return The row numbers of the first step.
#'
#' @noRd
first_step_rows <- function(lp_df) {
  step <- lp_df[["step"]]
  if (!is.null(step) && !is.na(step[1])) {
    return(which(step == step[1]))
  }
  tokens <- lp_df$step_token
  same <- if (is.na(tokens[1])) {
    is.na(tokens)
  } else {
    !is.na(tokens) & tokens == tokens[1]
  }
  seq_len(match(FALSE, same, nomatch = length(same) + 1L) - 1L)
}
