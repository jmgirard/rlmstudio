# Helpers for the brace tests of cli call sites that show text from the server
# or the CLI. If such text reaches cli as a format string, cli runs its braces
# as R code. The probe then prints "EVALUATED" to standard output, and the
# braces are gone from what cli shows.

brace_probe <- '{cat("EVALUATED")}'

# The probe as `{.val}` shows a string: in double quotes, with its inner quotes
# escaped.
brace_probe_val <- encodeString(brace_probe, quote = '"')

# Run `code` and collect what it shows: its standard output, the text of each
# message, and the error it raises, if any. Each message is muffled.
capture_shown <- function(code) {
  messages <- character(0)
  error <- NULL
  stdout <- utils::capture.output(
    tryCatch(
      withCallingHandlers(
        code,
        message = function(m) {
          messages <<- c(messages, conditionMessage(m))
          invokeRestart("muffleMessage")
        }
      ),
      error = function(e) error <<- e
    )
  )
  list(
    stdout = paste(stdout, collapse = "\n"),
    messages = paste(messages, collapse = ""),
    error = error
  )
}
