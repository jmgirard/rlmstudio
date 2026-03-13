# Getting Started with LM Studio: GUI Workflow

The `rlmstudio` package bridges the gap between R and local Large
Language Models by wrapping the LM Studio CLI and its REST API. This
vignette covers the **GUI Workflow**, which is best for visual users on
desktop environments like macOS, Windows, and Linux desktops.

While the R package provides functions to manage the entire lifecycle of
a local LLM, the LM Studio desktop application provides an excellent
visual search function for finding new models and exploring advanced
configurations beyond what the API can currently do. You can seamlessly
mix and match: use the GUI to discover and tweak models, and use R to
automate your chatting and data processing.

## Setup and Installation

This package relies on the LM Studio CLI. If you do not have LM Studio
installed or need to update your version, the package provides a
convenient setup function.

For desktop users, you can use the `"browser"` method to open the
official download page.

``` r
library(rlmstudio)

# Open the download page in your default browser
install_lmstudio(method = "browser")
## ℹ Opening the LM Studio download page in your default browser...
## ! Please install or update the software, restart R, and try again.
```

## Step-by-Step Guide

### 1. Start the Server

You have two options for starting the local server. You can open the LM
Studio desktop application, navigate to the Developer or Local Server
tab, and click “Start”. Alternatively, you can start it directly from R.

``` r
# Start the local server on the default port
lms_server_start()
## ✔ LM Studio server started successfully on the default port.
```

### 2. Finding and Managing Models

The LM Studio GUI shines when it comes to discovering models. You can
use its built-in search bar to browse Hugging Face, filter by
compatibility, and select specific quantizations.

However, if you already know the exact identifier of the model you want,
you can download it and manage your inventory directly from R.

``` r
# Download a model using its identifier
job_id <- lms_download("qwen/qwen3-4b-2507")
lms_download_status(job_id)
## ── Download Job: "job_493c7c9ded"
## Status: completed
## Progress: 100% (2.12 GB / 2.12 GB)

# View all downloaded models
models <- list_models()

# Filter for unloaded text models
unloaded_llms <- models |>
  subset(type == "llm" & state == "unloaded")
unloaded_llms
##       state  type   display_name                 key  architecture  size_gb
## 1  unloaded   llm  Qwen3 4B 2507  qwen/qwen3-4b-2507         qwen3     2.12
```

### 3. Loading Models

Before you can chat with a model, you must load it into system memory.

``` r
# Standard load
lms_load("qwen/qwen3-4b-2507")
## ✔ Model "qwen/qwen3-4b-2507" loaded and verified. [7.5s]
```

### 4. Chatting

The
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
function is designed for simple interactions.

``` r
response <- lms_chat(
  model = "qwen/qwen3-4b-2507",
  input = "Say hello!",
  system_prompt = "Answer in rhymes."
)

cat(response)
## Hello there! 🌟
## With a wave and a grin, I'm here to shine!
## Like a spark in the night, bright and bold,
## I'm your friend, ready to unfold!
##
## So take a breath, let the joy take flight—
## I’m all smiles, and a tale to write!
## From the stars to the ground, I’ll spin a rhyme,
## Just say the word, and I’ll be on time!
##
## So say hello again, or just "hi,"
## I’m here to keep things light and *sigh*! 😊
## What’s on your mind? I’ll meet you there—
## With a rhyme, a laugh, and a spark to spare! ✨
```

For more complex use cases like adjusting temperatures, utilizing
structured tool calling, or accessing raw API responses, simply pass
additional arguments to
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md).

``` r
advanced_response <- lms_chat(
  model = "qwen/qwen3-4b-2507",
  input = "Explain variance.",
  temperature = 0.2,
  simplify = FALSE
)

# Access the structured list
advanced_response
## $model_instance_id
## [1] "qwen/qwen3-4b-2507"
##
## $output
## $output[[1]]
## $output[[1]]$type
## [1] "message"
##
## $output[[1]]$content
## [1] "**Variance** is a statistical measure that quantifies the spread or dispersion of a set of data points around their mean (average value). It tells us how much the individual data points deviate from the average.\n\n### Key Points About Variance:\n\n1. **Definition**:\n   - Variance is the average of the squared differences between each data point and the mean.\n   - Mathematically, for a dataset \\( x_1, x_2, \\ldots, x_n \\), the **population variance** is:\n     \\[\n     \\sigma^2 = \\frac{1}{n} \\sum_{i=1}^{n} (x_i - \\mu)^2\n     \\]\n     where:\n     - \\( \\mu \\) is the population mean,\n     - \\( n \\) is the total number of data points.\n\n   - For a **sample** (used in real-world data), we use \\( n-1 \\) instead of \\( n \\) to correct for bias (this is called **sample variance**):\n     \\[\n     s^2 = \\frac{1}{n-1} \\sum_{i=1}^{n} (x_i - \\bar{x})^2\n     \\]\n     where \\( \\bar{x} \\) is the sample mean.\n\n2. **Interpretation**:\n   - A **low variance** means the data points are close to the mean and to each other (i.e., the data is tightly clustered).\n   - A **high variance** means the data points are spread out over a wide range (i.e., the data is more dispersed).\n\n3. **Why Square the Differences?**\n   - Squaring the differences ensures that all deviations are positive, preventing positive and negative deviations from canceling each other out.\n   - It also gives more weight to larger deviations.\n\n4. **Units**:\n   - Variance is expressed in **square units** of the original data (e.g., if data is in meters, variance is in square meters). This can make interpretation difficult.\n\n5. **Relation to Standard Deviation**:\n   - The **standard deviation** is the square root of the variance and is expressed in the same units as the original data, making it easier to interpret.\n\n---\n\n### Example:\nConsider the dataset: 4, 6, 8, 10, 12\n\n- Mean = \\( \\frac{4+6+8+10+12}{5} = 8 \\)\n- Deviations from mean: \\( -4, -2, 0, 2, 4 \\)\n- Squared deviations: \\( 16, 4, 0, 4, 16 \\)\n- Sum of squared deviations = \\( 16+4+0+4+16 = 40 \\)\n- Variance (population) = \\( \\frac{40}{5} = 8 \\)\n- Sample variance = \\( \\frac{40}{4} = 10 \\)\n\nSo, the variance is **8** (population) or **10** (sample).\n\n---\n\n### In Summary:\n> **Variance measures how spread out the data is from the mean.**  \n> A low variance indicates consistency; a high variance indicates variability.\n\nIt's a fundamental concept in statistics used in fields like finance (risk assessment), quality control, and machine learning (feature scaling)."
##
##
##
## $stats
## $stats$input_tokens
## [1] 12
##
## $stats$total_output_tokens
## [1] 711
##
## $stats$reasoning_output_tokens
## [1] 0
##
## $stats$tokens_per_second
## [1] 33.29417
##
## $stats$time_to_first_token_seconds
## [1] 0.382
##
##
## $response_id
## [1] "resp_5f480db79f250b19cd1fd5063112b44a2583f6ae97ef3320"
```

### 5. Teardown

To free up memory and system resources when you are finished, it is best
practice to unload your models and stop the local server. Closing the LM
Studio GUI will also perform this cleanup if you forget.

``` r
# Unload the model
lms_unload("qwen/qwen3-4b-2507")
## ✔ Model "qwen/qwen3-4b-2507" unloaded successfully. [391ms]

# Stop the server
lms_server_stop()
## ✔ LM Studio server stopped successfully.
```
