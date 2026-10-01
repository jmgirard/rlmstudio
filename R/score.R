#' Calculate Expected Scores and Uncertainty from Logprobs
#'
#' Takes a logprobs dataframe (from an \code{lms_chat_result}) and calculates
#' the weighted average score, normalized probabilities, and uncertainty
#' metrics for the first step of the reply, where the rating is.
#'
#' The function reads the rows of the first step only. If \code{lp_df} has a
#' \code{step} column and its first value is not \code{NA}, these are the rows
#' whose \code{step} equals that value, wherever they sit in the frame. A later
#' step with the same token as the first step does not count. Otherwise, these
#' are the first run of consecutive rows whose \code{step_token} is identical
#' to that of the first row, with \code{NA} equal to \code{NA}. In that case,
#' with no \code{step} column or a first \code{step} of \code{NA}, two
#' adjacent steps with the same token count as one step.
#'
#' Of those rows, the function keeps the candidates whose token, read as a
#' number, is in \code{scale}. Candidates that give the same label, such as
#' \code{"3"}, \code{" 3"}, and \code{"3.0"}, are summed into one label. The
#' probabilities of the labels are then scaled to sum to 1.
#'
#' @param lp_df A dataframe of logprobs (e.g., \code{x$logprobs}).
#' @param scale Numeric vector. The valid labels (e.g., \code{1:5}).
#'
#' @return A named list containing three numeric elements
#'   (\code{expected_value}, \code{weighted_sd}, \code{entropy}) and a
#'   \code{data.frame} named \code{probabilities} with columns \code{label} and
#'   \code{prob}. \code{probabilities} has one row per label, in the order in
#'   which each label first appears, and \code{entropy} is computed over these
#'   rows. Returns \code{NULL} if \code{lp_df} is \code{NULL} or has no rows.
#'   Aborts if no candidate of the first step is in \code{scale}.
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
#'   step = rep(1L, 3),
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

  # Convert logprobs to raw probabilities
  raw <- exp(candidates$candidate_logprob[valid_idx])
  # Sum the candidates that give the same label, such as "3" and " 3", in
  # the order in which each label first appears
  vals <- unique(nums[valid_idx])
  probs <- vapply(vals, \(v) sum(raw[nums[valid_idx] == v]), numeric(1))
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
