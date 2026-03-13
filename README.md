
# rlmstudio

**Disclaimer:** This is an unofficial, community-maintained R package.
It is not affiliated with, endorsed by, or maintained by the creators of
LM Studio.

The `rlmstudio` package provides an R interface to the [LM
Studio](https://lmstudio.ai/) CLI and REST API. It allows you to
download local Large Language Models (LLMs), manage server instances,
load or unload models into memory, and generate text directly from your
R console or scripts.

## Installation

You can install the development version of `rlmstudio` from GitHub with:

``` r
# install.packages("remotes")
remotes::install_github("jmgirard/rlmstudio")
```

## Setup and Prerequisites

This package relies on the LM Studio CLI (version 0.4.0 or higher) and
the new v1 REST API. If you do not have LM Studio installed or need to
update your version, the package provides a convenient setup function.

``` r
library(rlmstudio)

# This will check your installation and offer to open the download page
# or perform a headless installation depending on your operating system.
install_lmstudio()
```

## Quick Start

The standard workflow involves starting the LM Studio server, loading a
model into memory, chatting with it, and then cleaning up your
environment.

For a deeper dive into the package architecture and a detailed
explanation of how to use LM Studio with a visual GUI versus a headless
background daemon, please see the `vignette("getting-started")`.

### 1. Start the Server

Before you can load models or generate text, you need to start the LM
Studio backend server.

``` r
# Start the server on the default port (1234)
lms_server_start()
## ✔ LM Studio server started successfully on the default port.
```

*(Note for headless environments like remote servers or Docker
containers: You must start the background daemon first using
`lms_daemon_start()` before starting the server).*

### 2. Find and Load a Model

You can see which models you currently have available on your machine
using `list_models()`.

``` r
# Returns a clean data frame of available models
my_models <- list_models()
my_models
##      state  type  display_name                  key  architecture  size_gb
## 1 unloaded   llm  Gemma 3n E4B  google/gemma-3n-e4b       gemma3n     5.46
## 2 unloaded   llm   Gemma 3 12B   google/gemma-3-12b        gemma3     7.51
```

If you do not have a model yet, you can download one using its Hugging
Face repository or LM Studio catalog identifier.

``` r
# Download a lightweight model
job_id <- lms_download("google/gemma-3-1b")
lms_download_status(job_id)
## ── Download Job: "job_02c8a1f86e"
## Status: completed
## Progress: 100% (0.72 GB / 0.72 GB)
```

Once a model is downloaded and available, load it into memory.

``` r
# Load the model
lms_load("google/gemma-3-1b", flash_attention = TRUE)
## ✔ Model "google/gemma-3-1b" loaded and verified. [10.1s]
```

### 3. Chat

Use the `lms_chat()` function for quick and easy interactions.

``` r
response <- lms_chat(
  model = "google/gemma-3-1b",
  input = "What are the capitals of each country in North America?"
)

cat(response)
## Okay, here’s a list of the capitals of each country in North America:
##
## *   **Canada:** Ottawa
## *   **Mexico:** Mexico City
## *   **United States of America:** Washington, D.C.
## *   **Cuba:** Havana
## *   **Dominican Republic:** Santo Domingo
## *   **Jamaica:** Kingston
## *   **Bahamas:** Nassau
## *   **Trinidad and Tobago:** Port of Grace
##
## Would you like me to provide more details about any of these countries or their capitals?
```

If you need access to advanced features like Model Context Protocol
(MCP) integrations, structured tool calling, or granular control over
inference parameters, use the `lms_chat_advanced()` function instead.

### 4. Batch Processing

If you have a collection of documents or prompts to process,
`lms_chat_batch()` allows you to iterate over a vector of inputs and
capture the results in a tidy format.

``` r
prompts <- c(
  "Summarize the benefits of local LLMs.",
  "Explain why privacy matters in AI."
)

# Process all prompts and return a data frame
results <- lms_chat_batch(
  model = "google/gemma-3-1b",
  inputs = prompts,
  system_prompt = "Answer in two sentences or less."
)

print(results)
## [1] "Local LLMs offer significant benefits like improved privacy, reduced reliance on cloud services, and increased control over data. They also often demonstrate superior performance within specific domains due to training on localized datasets."
## [2] "Privacy matters in AI because sophisticated algorithms require vast amounts of data, and this data often includes personal information. Without adequate safeguards and regulations, AI systems can violate individuals’ privacy rights and lead to potential misuse of sensitive data."
```

### 5. Clean Up

When you are finished, it is good practice to unload the model from
memory and shut down the local server to free up system resources.

``` r
# Unload the specific model
lms_unload("google/gemma-3-1b")
## ✔ Model "google/gemma-3-1b" unloaded successfully. [382ms]

# Stop the local server
lms_server_stop()
## ✔ LM Studio server stopped successfully.
```
