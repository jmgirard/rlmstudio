# Helper function to gracefully skip tests when the CLI is missing
skip_if_no_lms <- function() {
  if (Sys.which("lms") == "") {
    testthat::skip("The 'lms' CLI is not installed or not in the system PATH.")
  }
}
