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
