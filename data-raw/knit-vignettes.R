# Knit the vignette sources ahead of time against a live LM Studio.
#
# Each vignette has a source, vignettes/<name>.Rmd.orig, with live code.
# This script knits each source to vignettes/<name>.Rmd, which holds the
# code and its output as plain markdown. R CMD check and CRAN then build the
# vignettes from that markdown and never reach LM Studio.
#
# Run this from the repository root with LM Studio installed, the server
# stopped, no model loaded, and RLMSTUDIO_API_TOKEN set if your server
# requires a token:
#
#   Rscript data-raw/knit-vignettes.R
#   Rscript data-raw/knit-vignettes.R vignettes/getting-started.Rmd.orig
#
# With no arguments, it knits every vignettes/*.Rmd.orig file. The last line
# of each knitted .Rmd holds the MD5 sum of its source, and
# tests/testthat/test-vignette-knit.R fails for a source that changed after
# its knit.
#
# The script refuses to start if the server runs or a model is loaded. After
# each source, it unloads every model and stops the server, so each vignette
# starts from the same clean state. A chunk error stops the knit, and the
# .Rmd of that source is left as it was. A chunk warning does the same,
# unless the chunk sets the option expect_warning = TRUE. That option keeps
# the warning in the output. A chunk with warning = FALSE hides its warning,
# and a chunk with warning = NA sends it to the console. In both cases the
# knit goes on. The sources after the failing one
# are not knitted, and the sources before it keep their new output. Whatever
# happens, the script unloads every model and stops the server before it
# exits.
#
# The script needs pkgload and knitr. knitr is in Suggests. pkgload is a
# development tool that only the data-raw scripts use, and this directory
# never ships, so it stays out of DESCRIPTION.

for (pkg in c("pkgload", "knitr")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(
      "This script needs the ", pkg, " package. ",
      "Install it with install.packages(\"", pkg, "\").",
      call. = FALSE
    )
  }
}

pkgload::load_all(quiet = TRUE)

sources <- commandArgs(trailingOnly = TRUE)
if (length(sources) == 0) {
  sources <- list.files("vignettes", pattern = "\\.Rmd\\.orig$", full.names = TRUE)
}
missing <- sources[!file.exists(sources) | !grepl("\\.Rmd\\.orig$", sources)]
if (length(missing) > 0) {
  stop(
    "Each argument must be an existing .Rmd.orig file. Not usable: ",
    paste(missing, collapse = ", "),
    call. = FALSE
  )
}

lms <- lms_path()

# The instance identifiers that `lms ps --json` lists as loaded, or the
# model key of an instance that has no identifier.
loaded_models <- function() {
  out <- system2(lms, c("ps", "--json"), stdout = TRUE, stderr = FALSE)
  ps <- jsonlite::parse_json(paste(out, collapse = "\n"))
  vapply(
    ps,
    function(m) {
      id <- m[["identifier"]]
      if (is.null(id)) id <- m[["modelKey"]]
      as.character(id)
    },
    ""
  )
}

# Whether `lms server status --json` reports the server as running.
server_running <- function() {
  out <- system2(lms, c("server", "status", "--json"), stdout = TRUE, stderr = FALSE)
  isTRUE(jsonlite::parse_json(paste(out, collapse = "\n"))[["running"]])
}

if (server_running() || lms_server_ready()) {
  stop(
    "The LM Studio server is running. Stop it with `lms server stop` ",
    "and run this script again.",
    call. = FALSE
  )
}
models <- loaded_models()
if (length(models) > 0) {
  stop(
    "A model is loaded: ", paste(models, collapse = ", "), ". ",
    "Unload it with `lms unload --all` and run this script again.",
    call. = FALSE
  )
}

# Unload every model and stop the server.
teardown <- function() {
  system2(lms, c("unload", "--all"), stdout = FALSE, stderr = FALSE)
  system2(lms, c("server", "stop"), stdout = FALSE, stderr = FALSE)
}

# Knit one source to a temporary file, and copy it over the .Rmd only when
# the whole knit succeeded. A chunk error stops the knit with the chunk label.
# The chunks run in a new environment, so a chunk cannot change the variables
# of this function.
knit_source <- function(source) {
  target <- sub("\\.orig$", "", source)
  temp <- tempfile(fileext = ".Rmd")
  old_wd <- setwd(dirname(source))
  on.exit(setwd(old_wd), add = TRUE)
  knitr::opts_chunk$set(error = FALSE)
  # knit() sets the markdown output hooks only while every hook is at its
  # default, so set them here before the warning hook wraps one of them.
  knitr::render_markdown()
  on.exit(knitr::knit_hooks$restore(), add = TRUE)
  warned <- character()
  markdown_warning <- knitr::knit_hooks$get("warning")
  knitr::knit_hooks$set(warning = function(x, options) {
    if (!isTRUE(options$expect_warning)) {
      warned <<- c(warned, options$label)
    }
    markdown_warning(x, options)
  })
  withCallingHandlers(
    knitr::knit(
      basename(source),
      output = temp,
      quiet = TRUE,
      envir = new.env(parent = globalenv())
    ),
    error = function(e) {
      label <- knitr::opts_current$get("label")
      stop(
        "The chunk '", label, "' of ", source, " failed: ",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
  setwd(old_wd)
  warned <- unique(warned)
  if (length(warned) == 1) {
    stop(
      "The chunk '", warned, "' of ", source, " gave a warning, and the ",
      "chunk does not set expect_warning = TRUE.",
      call. = FALSE
    )
  }
  if (length(warned) > 1) {
    stop(
      "The chunks '", paste(warned, collapse = "', '"), "' of ", source,
      " gave warnings, and these chunks do not set expect_warning = TRUE.",
      call. = FALSE
    )
  }
  # The last line holds the MD5 sum of the source. A test compares it with
  # the source, so an edit to the source without a new knit fails the test.
  cat(
    "\n<!-- Knitted from ", basename(source), " with MD5 ",
    unname(tools::md5sum(source)), ". -->\n",
    file = temp, append = TRUE, sep = ""
  )
  if (!file.copy(temp, target, overwrite = TRUE)) {
    stop("Could not copy the knitted ", source, " to ", target, ".", call. = FALSE)
  }
  message("Knitted ", source, " to ", target)
}

failed <- FALSE
tryCatch(
  for (source in sources) {
    knit_source(source)
    teardown()
  },
  error = function(e) {
    message(conditionMessage(e))
    failed <<- TRUE
  },
  finally = {
    # on.exit() never runs at the top level of Rscript, so the teardown
    # goes here. It runs after a chunk error too.
    teardown()
  }
)
if (failed) {
  quit(status = 1)
}
