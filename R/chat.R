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
#'   vector of the model's response. Otherwise, invisibly returns the system exit code.
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
  args <- c("chat")

  if (!is.null(model)) {
    args <- c(args, model)
  }
  if (!is.null(prompt)) {
    args <- c(args, "--prompt", prompt)
  }
  if (!is.null(system_prompt)) {
    args <- c(args, "--system-prompt", system_prompt)
  }
  if (isTRUE(stats)) {
    args <- c(args, "--stats")
  }
  if (!is.null(ttl)) {
    args <- c(args, "--ttl", as.character(ttl))
  }

  # Handle the single-prompt capture mode
  if (isTRUE(capture) && !is.null(prompt)) {
    res <- system2("lms", args = args, stdout = TRUE)

    status <- attr(res, "status")
    if (!is.null(status) && status != 0) {
      cli::cli_abort("Chat request failed. Exit code: {.val {status}}.")
    }
    return(res)
  }

  # Otherwise, let the user interact with the terminal or print standard output
  status <- system2("lms", args = args)

  if (status != 0) {
    cli::cli_abort("Chat session ended with an error. Exit code: {.val {status}}.")
  }

  invisible(status)
}
