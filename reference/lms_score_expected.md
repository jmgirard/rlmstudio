# Calculate Expected Scores and Uncertainty from Logprobs

Takes a logprobs dataframe (from an `lms_chat_result`) and calculates
the weighted average score, normalized probabilities, and uncertainty
metrics for the first step of the reply, where the rating is.

## Usage

``` r
lms_score_expected(lp_df, scale = 1:5)
```

## Arguments

- lp_df:

  A dataframe of logprobs (e.g., `x$logprobs`).

- scale:

  Numeric vector. The valid labels (e.g., `1:5`).

## Value

A named list containing three numeric elements (`expected_value`,
`weighted_sd`, `entropy`) and a `data.frame` named `probabilities` with
columns `label` and `prob`. `probabilities` has one row per label, in
the order in which each label first appears, and `entropy` is computed
over these rows. Returns `NULL` if `lp_df` is `NULL` or has no rows.
Aborts if no candidate of the first step is in `scale`.

## Details

The function reads the rows of the first step only. If `lp_df` has a
`step` column and its first value is not `NA`, these are the rows whose
`step` equals that value, wherever they sit in the frame. A later step
with the same token as the first step does not count. Otherwise, these
are the first run of consecutive rows whose `step_token` is identical to
that of the first row, with `NA` equal to `NA`. In that case, with no
`step` column or a first `step` of `NA`, two adjacent steps with the
same token count as one step. Both rules start from the first row, so
keep the rows in reply order: a sorted frame can start with a later
step.

Of those rows, the function keeps the candidates whose token, read as a
number, is in `scale`. Candidates that give the same label, such as
`"3"`, `" 3"`, and `"3.0"`, are summed into one label. The probabilities
of the labels are then scaled to sum to 1.

## Examples

``` r
# Create a sample logprobs dataframe representing a model's generation step
mock_logprobs <- data.frame(
  step_token = rep("4", 3),
  step_logprob = rep(0, 3),
  candidate_token = c("4", "5", "3"),
  candidate_logprob = c(-0.105, -2.302, -3.506),
  step = rep(1L, 3),
  stringsAsFactors = FALSE
)

# Calculate the expected score and uncertainty metrics
lms_score_expected(mock_logprobs, scale = 1:5)
#> $expected_value
#> [1] 4.067975
#> 
#> $weighted_sd
#> [1] 0.3487363
#> 
#> $entropy
#> [1] 0.6454112
#> 
#> $probabilities
#>   label       prob
#> 1     4 0.87376233
#> 2     5 0.09710651
#> 3     3 0.02913116
#> 
```
