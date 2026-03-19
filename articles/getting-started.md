# Getting Started with LM Studio in R

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
#> ℹ Opening the LM Studio download page in your default browser...
#> ! Please install or update the software, restart R, and try again.
```

## Step-by-Step Guide

### 1. Start the Server

You have two options for starting the local server. You can open the LM
Studio desktop application, navigate to the Developer or Local Server
tab, and click “Start”. Alternatively, you can start it directly from R.

``` r
# Start the local server on the default port
lms_server_start()
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
```

``` r
# View all downloaded models
models <- list_models()

# Filter for unloaded text models
unloaded_llms <- models |>
  subset(type == "llm" & state == "unloaded")
unloaded_llms
```

### 3. Loading Models

Before you can chat with a model, you must load it into system memory.

``` r
# Standard load
lms_load("qwen/qwen3-4b-2507", flash_attention = TRUE)
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
```

### 5. Teardown

To free up memory and system resources when you are finished, it is best
practice to unload your models and stop the local server. Closing the LM
Studio GUI will also perform this cleanup if you forget.

``` r
# Unload the model
lms_unload("qwen/qwen3-4b-2507")

# Stop the server
lms_server_stop()
```
