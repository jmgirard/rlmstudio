# Each alert of the package that is not a lost-result report follows the
# `rlmstudio.quiet` option. Each case runs its call and gives the alert text
# that the call shows when the option is FALSE.

quiet_alert_cases <- list(
  list(
    label = "check_lms_version() with no CLI",
    alert = "LM Studio CLI is not installed.",
    run = function() {
      local_mocked_bindings(lms_path = function() stop("no CLI"))
      check_lms_version()
    }
  ),
  list(
    label = "check_lms_version() with output it cannot parse",
    alert = "Could not parse the LM Studio CLI version.",
    run = function() {
      local_mocked_bindings(lms_path = function() "lms")
      local_mocked_bindings(
        run = function(...) list(status = 0, stdout = "no version", stderr = ""),
        .package = "processx"
      )
      check_lms_version()
    }
  ),
  list(
    label = "check_lms_version() with a version below the minimum",
    alert = "is too old. Minimum required is",
    run = function() {
      local_mocked_bindings(lms_path = function() "lms")
      local_mocked_bindings(
        run = function(...) {
          list(status = 0, stdout = "lms version 0.3.9\n", stderr = "")
        },
        .package = "processx"
      )
      check_lms_version()
    }
  ),
  list(
    label = "install_lmstudio() with the browser method",
    alert = "Please install or update the software",
    run = function() {
      local_mocked_bindings(has_lms = function() FALSE)
      local_mocked_bindings(browseURL = function(...) NULL, .package = "utils")
      install_lmstudio(method = "browser")
    }
  ),
  list(
    label = "print() of a chat result with no logprobs",
    alert = "Log probability data is empty or missing.",
    run = function() {
      print(new_lms_chat_result(text = "Hi", logprobs = NULL))
    }
  )
)

test_that("each alert follows the rlmstudio.quiet option", {
  for (case in quiet_alert_cases) {
    test_that(case$label, {
      # The text that the call shows, on standard output and in messages,
      # with styles removed and runs of space squished, since cli wraps lines.
      shown_with <- function(quiet) {
        withr::local_options(rlmstudio.quiet = quiet)
        shown <- capture_shown(case$run())
        expect_null(shown$error)
        text <- cli::ansi_strip(paste(shown$stdout, shown$messages))
        gsub("\\s+", " ", text)
      }

      expect_no_match(shown_with(TRUE), case$alert, fixed = TRUE)
      expect_match(shown_with(FALSE), case$alert, fixed = TRUE)
    })
  }
})
