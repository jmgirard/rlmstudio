# Getting Started with LM Studio in R

``` r

library(rlmstudio)

model <- "google/gemma-3-1b"

knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)
```

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

For desktop users, you can run `install_lmstudio(method = "browser")` in
your console to open the official download page.

``` r

# Check if LM Studio is available on this system
has_lms()
#> [1] TRUE
```

## Step-by-Step Guide

### 1. Start the Server

You have two options for starting the local server. You can open the LM
Studio desktop application, navigate to the Developer or Local Server
tab, and click “Start”. Alternatively, you can start it directly from R.
The CLI returns before the REST API answers, so
[`lms_server_start()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_start.md)
keeps asking the REST API whether it is ready and returns once it
answers. The `wait` argument sets how many seconds it keeps asking, and
defaults to 10.

``` r

# Start the local server on the default port, and allow 30 seconds for it
lms_server_start(wait = 30)
#> ✔ LM Studio server started successfully on the default port.
```

A wait that runs out raises a warning and returns rather than aborting,
so the start call alone does not prove that the server is usable. Check
that it answers before you call it.
[`lms_server_ready()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_ready.md)
asks the host for a model list and reports `TRUE` only for an answer LM
Studio would give. It reports `FALSE` for a port held by another process
and for a server that turns your token away.

``` r

lms_server_ready()
#> [1] TRUE
```

### 2. Finding and Managing Models

The LM Studio GUI shines when it comes to discovering models. You can
use its built-in search bar to browse Hugging Face, filter by
compatibility, and select specific quantizations.

However, if you already know the exact identifier of the model you want,
you can download it and manage your inventory directly from R.

``` r

# Download a model using its identifier
job_id <- lms_download(model)
#> ℹ Initiating download for model: "google/gemma-3-1b"...
#> ✔ Initiating download for model: "google/gemma-3-1b"... [1s]
#> 
#> ✔ Model "google/gemma-3-1b" is already downloaded.

lms_download_status(job_id)
#> 
#> ── Download Job: "N/A"
#> Status: already_downloaded
```

### 3. Loading Models

Before you can chat with a model, you must load it into system memory.
We include the optional `flash_attention = TRUE` argument here, which
speeds up processing and reduces memory usage on supported hardware.

``` r

# Standard load
lms_load(model, flash_attention = TRUE)
#> ℹ Loading model: "google/gemma-3-1b"...
#> ✔ Model "google/gemma-3-1b" loaded and verified. [5.9s]
#> 
```

### 4. Chatting

Interact with the model by sending it text prompts. The
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
function takes a few key arguments to guide the AI’s response:

- `input`: This is your main message or question for the model.

- `system_prompt`: This is an optional set of background instructions.
  You use it to tell the AI how to behave, what role to play, or how to
  format its answers (like asking it to act as an expert R programmer).

*Note:* By default, each call to
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
starts a new conversation. The model does not remember earlier messages
or context from your R script. To continue a conversation, pass the
`response_id` attribute of the earlier reply as `previous_response_id`.
This works on the default route, `api_type = "openresponses"`, and on
`api_type = "native"`, but not on `api_type = "openai"`. See
[`?lms_chat`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
for details.

``` r

response <- lms_chat(
  model = model,
  input = "Say hello!",
  system_prompt = "Answer in rhymes."
)

cat(response)
#> Hello there, it’s a lovely day! 
#> Let’s chat and have some play. 
#> Say hello, it’s a joyful plea,
#> Come on say hello, you see!
```

### 5. Teardown

To free up memory and system resources when you are finished, it is best
practice to unload your models and stop the local server. Closing the LM
Studio GUI will also perform this cleanup if you forget.

``` r

# Unload the model
lms_unload(model)
#> ℹ Unloading model: "google/gemma-3-1b"...
#> ✔ Model "google/gemma-3-1b" unloaded successfully. [560ms]
#> 
```

``` r

# Stop the server
lms_server_stop()
#> ✔ LM Studio server stopped successfully.
```
