skip_if_no_lms <- function() {
  if (!has_lms()) {
    testthat::skip("LM Studio CLI is not installed.")
  }
}

skip_if_no_server <- function() {
  if (!is_server_running()) {
    testthat::skip("LM Studio local server is not running.")
  }
}
