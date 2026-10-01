# Text Analysis with LM Studio in R

``` r

library(rlmstudio)

model <- "google/gemma-3-1b"
embed_model <- "text-embedding-nomic-embed-text-v1.5"

knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)
```

This vignette shows how to use a local model to analyze a set of texts.
It sends a batch of prompts and gets the replies back as a data frame.
It asks for replies in a fixed shape, so that each field becomes a
column. It turns the token probabilities of a one-digit rating into a
score. It also turns texts into embedding vectors. The vignette
[`vignette("getting-started")`](https://jmgirard.github.io/rlmstudio/articles/getting-started.md)
covers the steps that come first: installing LM Studio, starting the
server, and downloading `google/gemma-3-1b`.

## Start the server

``` r

lms_server_start(wait = 30)
#> ✔ LM Studio server started successfully on the default port.
lms_server_ready()
#> [1] TRUE
```

## Quiet output

[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
prints messages while it loads a model, and
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
shows a progress bar while a batch runs. Set the `rlmstudio.quiet`
option to `TRUE` to hide both. Some warnings still show, such as the
warning that a batch gives about failed inputs. This vignette sets the
option here and sets it back before the teardown.

``` r

old_options <- options(rlmstudio.quiet = TRUE)
```

``` r

lms_load(model)
```

## A batch of prompts as a data frame

[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
sends each input as its own request. With `format = "data.frame"`, it
returns one row per input. The row holds the input, the reply text in
`output`, the id of the reply, and three token counts.

``` r

reviews <- c(
  "The food was great but the service was slow.",
  "Terrible. Never again.",
  "Best pizza in town, and the staff were friendly."
)
```

``` r

summaries <- lms_chat_batch(
  model,
  reviews,
  system_prompt = "Summarize the review in five words or fewer.",
  format = "data.frame",
  temperature = 0
)
names(summaries)
#> [1] "input"                   "output"                 
#> [3] "response_id"             "input_tokens"           
#> [5] "total_output_tokens"     "reasoning_output_tokens"
summaries[, c("input", "output")]
#>                                              input
#> 1     The food was great but the service was slow.
#> 2                           Terrible. Never again.
#> 3 Best pizza in town, and the staff were friendly.
#>                               output
#> 1       Excellent, but slow service.
#> 2 **A disappointing experience.** \n
#> 3                   Excellent pizza!
```

## Structured output as columns

A `schema` goes to the server as a JSON schema that the reply must
match. It needs `api_type = "openai"`, and the call aborts on any other
route. On `api_type = "openai"`, a data-frame batch with an object
schema adds one column per top-level property of the schema. A
`"string"` property gives a character column, and an `"integer"`
property gives an integer column.

``` r

schema <- list(
  type = "object",
  properties = list(
    sentiment = list(
      type = "string",
      enum = list("positive", "negative", "mixed")
    ),
    stars = list(type = "integer")
  ),
  required = list("sentiment", "stars")
)
rated <- lms_chat_batch(
  model,
  reviews,
  system_prompt = paste(
    "Give the sentiment of the review, and rate it from 1 to 5 stars,",
    "where 1 is the worst and 5 is the best."
  ),
  format = "data.frame",
  api_type = "openai",
  schema = schema,
  temperature = 0
)
rated[, c("input", "sentiment", "stars")]
#>                                              input sentiment stars
#> 1     The food was great but the service was slow.     mixed     4
#> 2                           Terrible. Never again.  negative     5
#> 3 Best pizza in town, and the staff were friendly.  positive     5
```

In this output, the model gave 5 stars to the negative review. A model
as small as `google/gemma-3-1b` makes mistakes of this kind, so read its
replies before you rely on them.

## A rating scored from token probabilities

A model that answers with one digit picks that digit from several
candidates. With `logprobs = TRUE` on the default route,
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
returns an object that holds the reply text and a data frame of log
probabilities, if the reply carries them. The data frame lists the
candidate tokens at each step of the reply, and its `step` column
numbers the steps from 1. The `top_logprobs` and `temperature` fields go
into the request body.

``` r

rating <- lms_chat(
  model = model,
  input = paste(
    "Rate how positive this review is from 1 to 5.",
    "Answer with one digit only.",
    "Review: The food was great but the service was slow."
  ),
  logprobs = TRUE,
  top_logprobs = 10,
  temperature = 0
)
rating$text
#> [1] "3\n"
head(rating$logprobs, 3)
#>   step_token step_logprob candidate_token candidate_logprob step
#> 1          3     -0.34375               3         -0.343750    1
#> 2          3     -0.34375               4         -1.546875    1
#> 3          3     -0.34375               5         -2.750000    1
```

[`lms_score_expected()`](https://jmgirard.github.io/rlmstudio/reference/lms_score_expected.md)
reads the rows of the first step, the rows whose `step` equals that of
the first row. In the reply above, those rows hold the candidates for
the digit. A later step with the same token does not count. For a data
frame with no `step` column, or whose first `step` is `NA`, it reads the
first run of rows with the same `step_token` as the first row. It keeps
the candidates whose token is a number in `scale`, and it adds up the
candidates that give the same label, such as `"3"` and `" 3"`. It then
scales the probabilities to sum to 1. It returns the expected value, the
weighted standard deviation, the entropy in bits, and the probability of
each label.

``` r

score <- lms_score_expected(rating$logprobs, scale = 1:5)
score$expected_value
#> [1] 3.342552
score$probabilities
#>   label         prob
#> 1     3 0.7176032364
#> 2     4 0.2154635645
#> 3     5 0.0646938939
#> 4     2 0.0021793830
#> 5     1 0.0000599222
```

## Embeddings

[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
turns each text into a vector of numbers. It returns a matrix with one
row per input text, in the order given. LM Studio comes with the
embedding model `text-embedding-nomic-embed-text-v1.5`.

``` r

lms_load(embed_model)
texts <- c(reviews, "The stock market fell sharply today.")
vectors <- lms_embed(embed_model, texts)
dim(vectors)
#> [1]   4 768

# The cosine similarity of each pair of texts
unit <- vectors / sqrt(rowSums(vectors^2))
round(unit %*% t(unit), 2)
#>      [,1] [,2] [,3] [,4]
#> [1,] 1.00 0.37 0.56 0.47
#> [2,] 0.37 1.00 0.36 0.44
#> [3,] 0.56 0.36 1.00 0.34
#> [4,] 0.47 0.44 0.34 1.00
```

## Loaded instances

[`list_instances()`](https://jmgirard.github.io/rlmstudio/reference/list_instances.md)
returns one row per loaded model instance. The columns hold the instance
id, the model key, the model type, the display name, and the load
configuration of the instance.

``` r

instances <- list_instances()
instances[, c("id", "type", "context_length")]
#>                                     id      type context_length
#> 1                    google/gemma-3-1b       llm           8192
#> 2 text-embedding-nomic-embed-text-v1.5 embedding           2048
```

## Teardown

``` r

# Set the option back to the value it had before this vignette
options(old_options)
```

[`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md)
unloads every loaded model instance.

``` r

lms_unload_all()
#> ℹ Found 2 loaded model instances. Unloading now...
#> ℹ Unloading model: "google/gemma-3-1b"...
#> ✔ Model "google/gemma-3-1b" unloaded successfully. [557ms]
#> 
#> ℹ Unloading model: "text-embedding-nomic-embed-text-v1.5"...
#> ✔ Model "text-embedding-nomic-embed-text-v1.5" unloaded successfully. [9ms]
#> 
#> ✔ All models unloaded successfully.
```

``` r

lms_server_stop()
#> ✔ LM Studio server stopped successfully.
```
