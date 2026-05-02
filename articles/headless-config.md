# Headless Configuration and Usage

The `rlmstudio` package provides robust support for running LM Studio in
completely headless environments. This is ideal for Linux servers,
Docker containers, remote cloud instances, and automated CI/CD pipelines
where a visual desktop application is unavailable or inconvenient.

To operate without a GUI, LM Studio relies on a background process
called the `llmster` daemon. This vignette will walk you through
managing the daemon, starting the local server, and fully automating
your local LLM workflows.

## Setup and Installation

If you are setting up a fresh remote server, you can use the package to
download and install the LM Studio CLI automatically via the terminal.

``` r

library(rlmstudio)

# Run the automated CLI installation script for Linux/macOS or Windows
install_lmstudio(method = "headless")
```

## Step-by-Step Guide

### 1. Start the Background Daemon

Unlike the desktop version where opening the app initializes the backend
engine, a headless environment requires you to start the engine
manually. You must start the `llmster` daemon before attempting to load
models or start the API server.

``` r

# Start the headless engine in the background
lms_daemon_start()
```

### 2. Start the Local Server

With the daemon running, you can now spin up the REST API server to
accept HTTP requests.

``` r

# Start the local server on the default port
lms_server_start()
```

### 3. Finding and Managing Models

Because you do not have the GUI’s visual search tool, you will need to
know the Hugging Face repository or the LM Studio catalog identifier for
the model you want to use.

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

### 4. Loading Models

Allocate the model to your system’s memory (RAM/VRAM) so it is ready for
inference.

``` r

# Load the model
lms_load("google/gemma-3-1b", flash_attention = TRUE)
```

### 5. Chatting

Interact with the model exactly as you would in a desktop environment.

``` r

response <- lms_chat(
  model = "google/gemma-3-1b",
  input = "Provide just the str_extract() pattern to match all text after the third comma.",
  system_prompt = "You are an expert R programmer familiar with the tidyverse."
)

cat(response)
```

### 6. Teardown and Cleanup

In a headless environment, managing your system resources is critical.
When your script finishes, you should explicitly tear down the entire
stack to free up memory and stop background processes.

``` r

# 1. Unload the model from memory
lms_unload("google/gemma-3-1b")

# 2. Stop the API server
lms_server_stop()

# 3. Stop the background daemon
lms_daemon_stop()
```

## Bonus: Pipeline Automation

If you are writing a script that just needs to run a quick job and exit,
managing the daemon state manually can be tedious. The
[`with_lms_daemon()`](https://jmgirard.github.io/rlmstudio/reference/with_lms_daemon.md)
wrapper handles the setup and guaranteed teardown of the background
engine automatically.

``` r

# The daemon will start, the code will run, and the daemon will stop on exit.
results <- with_lms_daemon({
  lms_server_start()
  lms_load("google/gemma-3-1b")

  res <- lms_chat("google/gemma-3-1b", "Is the daemon running?")

  lms_server_stop()
  res
})
```
