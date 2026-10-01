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
# With no arguments, it knits every vignettes/*.Rmd.orig file.
#
# The script refuses to start if the server runs or a model is loaded, so
# each vignette starts from the same clean state. A chunk error stops the
# knit, and the .Rmd of that source is left as it was. The sources after the
# failing one are not knitted, and the sources before it keep their new
# output. Whatever happens, the script unloads every model and stops the
# server before it exits.
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

# Knit one source to a temporary file, and copy it over the .Rmd only when
# the whole knit succeeded. A chunk error stops the knit with the chunk label.
knit_source <- function(source) {
  target <- sub("\\.orig$", "", source)
  temp <- tempfile(fileext = ".Rmd")
  old_wd <- setwd(dirname(source))
  on.exit(setwd(old_wd), add = TRUE)
  knitr::opts_chunk$set(error = FALSE)
  withCallingHandlers(
    knitr::knit(basename(source), output = temp, quiet = TRUE),
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
  file.copy(temp, target, overwrite = TRUE)
  message("Knitted ", source, " to ", target)
}

failed <- FALSE
tryCatch(
  for (source in sources) {
    knit_source(source)
  },
  error = function(e) {
    message(conditionMessage(e))
    failed <<- TRUE
  },
  finally = {
    # on.exit() never runs at the top level of Rscript, so the teardown
    # goes here. It runs after a chunk error too.
    system2(lms, c("unload", "--all"), stdout = FALSE, stderr = FALSE)
    system2(lms, c("server", "stop"), stdout = FALSE, stderr = FALSE)
  }
)
if (failed) {
  quit(status = 1)
}
