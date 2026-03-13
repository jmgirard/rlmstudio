#' Get the absolute path to the LMS executable
#' @noRd
get_lms_path <- function() {
  cmd <- Sys.which("lms")
  if (cmd == "") {
    cli::cli_abort(c(
      "x" = "The LM Studio CLI ({.val lms}) was not found on your system.",
      "i" = "Please install it or run {.fun install_lmstudio} to configure your environment."
    ))
  }
  unname(cmd)
}
