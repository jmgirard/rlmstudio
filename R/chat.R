build_args_model_chat <- function(model = NULL, prompt = NULL, system_prompt = NULL,
                                  stats = FALSE, ttl = NULL) {
  args <- "chat"

  if (!is.null(model)) args <- c(args, model)
  if (!is.null(prompt)) args <- c(args, "--prompt", prompt)
  if (!is.null(system_prompt)) args <- c(args, "--system-prompt", system_prompt)
  if (isTRUE(stats)) args <- c(args, "--stats")
  if (!is.null(ttl)) args <- c(args, "--ttl", as.character(ttl))

  args
}

model_chat <- function(model = NULL, prompt = NULL, system_prompt = NULL,
                       stats = FALSE, ttl = NULL, capture = FALSE) {

  args <- build_args_model_chat(
    model = model,
    prompt = prompt,
    system_prompt = system_prompt,
    stats = stats,
    ttl = ttl
  )

  if (isTRUE(capture) && !is.null(prompt)) {
    res <- processx::run("lms", args, error_on_status = FALSE)

    if (res$status != 0) {
      cli::cli_abort("Chat request failed. Exit code: {.val {res$status}}.")
    }

    # Split the output into lines
    lines <- strsplit(res$stdout, "\r?\n")[[1]]

    # Clean up ANSI escape sequences and carriage returns
    lines <- cli::ansi_strip(lines)
    lines <- gsub("\r", "", lines)

    # Drop any empty lines that result from the cleanup
    lines <- lines[lines != ""]

    return(lines)
  }

  res <- processx::run("lms", args, stdout = "", stderr = "", error_on_status = FALSE)

  if (res$status != 0) {
    cli::cli_abort("Chat session ended with an error. Exit code: {.val {res$status}}.")
  }

  invisible(res$status)
}
