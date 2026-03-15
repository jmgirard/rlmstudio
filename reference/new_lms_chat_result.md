# Create a new LM Studio chat result

Internal constructor to create a structured object for responses
containing log probabilities.

## Usage

``` r
new_lms_chat_result(text = character(), logprobs = data.frame())
```

## Arguments

- text:

  Character. The generated text response.

- logprobs:

  Dataframe. The token-level probability data.

## Value

An object of class `lms_chat_result`.
