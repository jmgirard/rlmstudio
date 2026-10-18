# Getting Started with LM Studio in R

A large language model is a program that writes text in reply to text
that you give it. The text that you give it is a prompt. LM Studio is a
desktop app that downloads such models and runs them on your own
computer. The rlmstudio package lets you control LM Studio from R. This
vignette takes you from installing LM Studio to your first replies from
a model.

## Install LM Studio

LM Studio comes with a command-line tool called `lms`. A command-line
tool is a program that you run by typing commands, and the messages of
the package call it the CLI. The package uses `lms` to start and stop
parts of LM Studio. If you do not have LM Studio yet, run
`rlmstudio::install_lmstudio(method = "browser")`. It opens the LM
Studio download page in your web browser. After you install LM Studio,
open the app once, and then restart R. The LM Studio documentation says
that you need to run LM Studio at least once before you can use `lms`.

Load the package and check that R can find LM Studio.

``` r

library(rlmstudio)

# TRUE if R finds the lms tool
has_lms()
#> [1] TRUE

# TRUE if the lms tool is version 0.4.0 or later
check_lms_version()
#> ✔ LM Studio CLI is using the modern architecture (0.4.0+).
#> [1] TRUE
```

If either call returns `FALSE`, install or update LM Studio before you
go on.

## Start the server

R talks to LM Studio through a local server. A local server is a program
on your own computer that answers requests from other programs, such as
R. By default, the package sends its requests to
`http://localhost:1234`. That is an address on your own computer.

[`lms_server_start()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_start.md)
starts the server. Then it waits until LM Studio answers. The `wait`
argument sets about how many seconds it waits. If the wait runs out, the
function gives a warning, and your script goes on. So call
[`lms_server_ready()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_ready.md)
next. It returns `TRUE` only when LM Studio answers.

The number at the end of the address, 1234, is the port. Without a
`port` argument, the server starts on the port that it used last time.
If that port is not 1234, the calls of this vignette do not reach the
server. So pass `port = 1234`.

``` r

# Start the server on port 1234, and wait about 30 seconds for it to answer
lms_server_start(port = 1234, wait = 30)
#> ✔ LM Studio server started successfully on port 1234.

# TRUE if LM Studio answers
lms_server_ready()
#> [1] TRUE
```

## Find a model

A model key is the name that you give R to choose a model, such as
`"google/gemma-3-1b"`.
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
shows the models that LM Studio has on your computer, one row for each
model. The `key` column holds the model key. In the `type` column, `llm`
marks a large language model, the kind that you chat with. The `state`
column says whether the model is in memory, which a later section
explains.

``` r

# The models on this computer, one row each
list_models()
#>      state      type          display_name                                  key
#> 1 unloaded       llm             Lfm2 350m                     liquid/lfm2-350m
#> 2 unloaded       llm    Functiongemma 270m            google/functiongemma-270m
#> 3 unloaded       llm           Gemma 4 E4B                   google/gemma-4-e4b
#> 4 unloaded       llm   Gemma 4 26B A4B QAT           google/gemma-4-26b-a4b-qat
#> 5 unloaded       llm         Qwen3 4B 2507                   qwen/qwen3-4b-2507
#> 6 unloaded       llm            Gemma 3 1B                    google/gemma-3-1b
#> 7 unloaded embedding Nomic Embed Text v1.5 text-embedding-nomic-embed-text-v1.5
#>   architecture size_gb
#> 1         lfm2    0.36
#> 2  gemma3_text    0.53
#> 3       gemma4    6.39
#> 4       gemma4   14.57
#> 5        qwen3    2.12
#> 6  gemma3_text    0.72
#> 7         <NA>    0.08
```

On a new install, you have no model to chat with yet. LM Studio comes
with an embedding model, a model that turns text into numbers and does
not chat. The next section downloads a model that you can chat with.
This vignette uses `google/gemma-3-1b`, a small model. Keep its key in a
variable, so that each call below can use it.

``` r

model <- "google/gemma-3-1b"
```

To find other models, go to the LM Studio model catalog at
<https://lmstudio.ai/models>. The address of a model’s own page ends
with its key. For example, the page of the model above is
<https://lmstudio.ai/models/google/gemma-3-1b>, so its key is
`google/gemma-3-1b`. Some catalog pages show a family of models, such as
the sizes of one model. Open the page of one model in the family to get
its key. A model page can also show an `lms get` command. The model name
in that command is not always a key that
[`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md)
accepts, so use the end of the page address.

## Download the model

[`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md)
asks LM Studio to download a model. For a model that is already on your
computer, it returns `"already_downloaded"`. For a new model, it returns
a job id, a string that names the download. Pass the job id to
[`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md)
to see the status of the download.

The `status` element of the result holds the status. While LM Studio
downloads the model, it is `"downloading"`. Call
[`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md)
again until it is `"completed"`, which means that the download finished.
If it is `"failed"`, the download did not finish. If you pass
`"already_downloaded"` to
[`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md),
the status is `"already_downloaded"`.

When the output below was made, the model was already on the computer.
So the output shows `"already_downloaded"`.

``` r

# Download the model, or find that it is already on disk
job_id <- lms_download(model)
#> ℹ Initiating download for model: "google/gemma-3-1b"...
#> ✔ Initiating download for model: "google/gemma-3-1b"... [1.4s]
#> 
#> ✔ Model "google/gemma-3-1b" is already downloaded.
job_id
#> [1] "already_downloaded"

# The status of the download
status <- lms_download_status(job_id)
status$status
#> [1] "already_downloaded"
```

## Put the model in memory

Loading a model means that LM Studio reads it from disk into memory. A
chat with a model that is not loaded can make LM Studio load it, but
then the chat waits for the load.
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
loads the model before the chat.

``` r

# Read the model into memory
lms_load(model)
#> ℹ Loading model: "google/gemma-3-1b"...
#> ✔ Model "google/gemma-3-1b" loaded and verified. [5.4s]
#> 
```

## Chat with the model

[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
sends one prompt to the model and returns the reply as text. The `input`
argument holds your prompt.

A system prompt is a set of instructions that the model gets with your
prompt. Use it to set the role, the tone, or the length of the reply.
The `system_prompt` argument of
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
holds it.

``` r

# Send one prompt, with a system prompt
reply <- lms_chat(
  model = model,
  input = "Say hello to a new R user.",
  system_prompt = "Answer in one short sentence."
)

# Print the text of the reply
cat(reply)
#> Hello there, welcome to the world of R! 😊
```

## Send several prompts in one call

A batch is a set of prompts that you send in one call, such as one
prompt for each row of your data.
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
sends each prompt in `inputs` as its own request, with the same system
prompt. It returns one reply for each prompt, in the order of the
prompts.

``` r

questions <- c(
  "Name a fruit.",
  "Name a color.",
  "Name a planet."
)

# One reply for each prompt, in the same order
answers <- lms_chat_batch(
  model = model,
  inputs = questions,
  system_prompt = "Answer with one word."
)
answers
#> [1] "Apple \n" "Blue."    "Mars "

# Remove the spaces and line breaks around each reply
trimws(answers)
#> [1] "Apple" "Blue." "Mars"
```

A reply can carry extra spaces or line breaks, and a model does not
always follow its system prompt. So read the replies before you use
them.

[`vignette("text-analysis")`](https://jmgirard.github.io/rlmstudio/articles/text-analysis.md)
shows how to get the replies of a batch as a data frame, with one row
for each prompt.

## Clean up

When you are done, unload the model to free its memory, and stop the
server.

``` r

# Remove the model from memory
lms_unload(model)
#> ℹ Unloading model: "google/gemma-3-1b"...
#> ✔ Model "google/gemma-3-1b" unloaded successfully. [590ms]
#> 

# Stop the local server
lms_server_stop()
#> ✔ LM Studio server stopped successfully.
```

## Without the desktop app

You can also run LM Studio without the desktop app, for example on a
remote computer that you reach over a network. This is called a headless
setup.
[`vignette("headless-config")`](https://jmgirard.github.io/rlmstudio/articles/headless-config.md)
shows how to install and use LM Studio that way.
