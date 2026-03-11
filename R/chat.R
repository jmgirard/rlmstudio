#' @noRd
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

#' Chat with a local model
#'
#' Starts an interactive chat session with a local model in the terminal, or
#' sends a single prompt and returns the response.
#'
#' @param model Character. Identifier of the model to use. If omitted, the CLI will prompt you.
#' @param prompt Character. Send a one-off prompt and exit without staying interactive.
#' @param system_prompt Character. Custom system prompt for the chat.
#' @param stats Logical. Show detailed prediction statistics after each response. Defaults to FALSE.
#' @param ttl Integer. Seconds to keep the model loaded after the chat ends.
#' @param capture Logical. If `TRUE` and a `prompt` is provided, the function will
#'   return the response as a character vector instead of printing it to the console.
#'
#' @return If `capture = TRUE` and a `prompt` is provided, returns a character
#'   vector of the model's response, stripped of ANSI escape codes. Otherwise,
#'   invisibly returns the system exit code.
#' @export
#'
#' @examples
#' \dontrun{
#' # Start an interactive chat
#' model_chat("llama-3.1-8b")
#'
#' # Send a one-off prompt and capture the text in R
#' response <- model_chat("llama-3.1-8b", prompt = "What is 2+2?", capture = TRUE)
#' }
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
