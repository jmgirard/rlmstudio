# Calculate Expected Scores and Uncertainty from Logprobs

Takes a logprobs dataframe (from an `lms_chat_result`) and calculates
the weighted average score, normalized probabilities, and uncertainty
metrics.

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

A list containing the `expected_value`, `weighted_sd`, `entropy`, and a
`data.frame` of normalized probabilities.

## Examples

``` r
# Create a sample logprobs dataframe representing a model's generation step
mock_logprobs <- data.frame(
  step_token = rep("4", 3),
  step_logprob = rep(0, 3),
  candidate_token = c("4", "5", "3"),
  candidate_logprob = c(-0.105, -2.302, -3.506),
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
