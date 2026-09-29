# The abort of a failed CLI run quotes the CLI text. Each function that runs
# the CLI and aborts on its exit code runs over the same texts here. cli wraps
# long bullets, so messages are compared after each whitespace run is
# collapsed to one space.

cli_squish <- function(x) gsub("\\s+", " ", trimws(x))

# Each entry runs one function so that it reaches its failure branch.
cli_callers <- list(
  lms_server_start = function() lms_server_start(wait = 0)
)

# Run `caller` against a CLI that returns `res`, and return the squished
# message of the error it raises, with what it printed.
cli_failure <- function(caller, res) {
  local_mocked_bindings(lms_path = function() "lms")
  local_mocked_bindings(run = function(...) res, .package = "processx")
  shown <- capture_shown(caller())
  expect_s3_class(shown$error, "error")
  list(
    message = cli_squish(conditionMessage(shown$error)),
    stdout = shown$stdout
  )
}

# The text after "The CLI said: " up to the first space. The cut tests use
# texts with no spaces, so this is the whole quoted text.
cli_quoted_word <- function(message) {
  hit <- regmatches(message, regexpr("The CLI said: \\S+", message))
  sub("The CLI said: ", "", hit, fixed = TRUE)
}

expect_cli_said <- function(message, text, name) {
  expect_true(
    grepl(paste("The CLI said:", text), message, fixed = TRUE),
    label = paste(name, message)
  )
}

bytes <- function(...) rawToChar(as.raw(c(...)))

test_that("the quoted text shows a byte that is not valid UTF-8 as <xx>", {
  stderr <- paste0("bad ", bytes(0xff), " here\n")
  for (name in names(cli_callers)) {
    warnings <- 0L
    got <- withCallingHandlers(
      cli_failure(cli_callers[[name]], list(status = 1, stderr = stderr)),
      warning = function(w) {
        warnings <<- warnings + 1L
        invokeRestart("muffleWarning")
      }
    )
    expect_cli_said(got$message, "bad <ff> here", name)
    expect_identical(warnings, 0L, info = name)
  }
})

test_that("the quoted text has no ANSI escape sequences", {
  # One text for each form: a color code, other cursor codes, and a terminal
  # link closed by ESC \ or by BEL.
  texts <- c(
    color = "\033[31mred\033[39m done",
    cursor = "\033[?25lhide\033[2K\033[1Gline done",
    link_st = "\033]8;;https://lmstudio.ai\033\\link\033]8;;\033\\ done",
    link_bel = "\033]8;;https://lmstudio.ai\alink\033]8;;\a done"
  )
  expected <- c(
    color = "red done",
    cursor = "hideline done",
    link_st = "link done",
    link_bel = "link done"
  )
  for (name in names(cli_callers)) {
    for (form in names(texts)) {
      got <- cli_failure(
        cli_callers[[name]],
        list(status = 1, stderr = texts[[form]])
      )
      expect_cli_said(got$message, expected[[form]], paste(name, form))
      expect_false(grepl("\033", got$message, fixed = TRUE), label = form)
      expect_false(grepl("lmstudio.ai", got$message, fixed = TRUE), label = form)
    }
  }
})

test_that("each whitespace run in the quoted text becomes one space", {
  stderr <- "line one\n\tline two  end\r\n  "
  for (name in names(cli_callers)) {
    got <- cli_failure(cli_callers[[name]], list(status = 1, stderr = stderr))
    expect_cli_said(got$message, "line one line two end", name)
  }
})

test_that("braces in the quoted text show as written and do not run", {
  for (name in names(cli_callers)) {
    got <- cli_failure(
      cli_callers[[name]],
      list(status = 1, stderr = brace_probe)
    )
    expect_cli_said(got$message, brace_probe, name)
    expect_false(grepl("EVALUATED", got$stdout, fixed = TRUE), label = name)
  }
})

test_that("a quoted text of more than 1000 characters keeps its last 1000", {
  stderr <- paste0(strrep("1", 500), strrep("2", 1000))
  for (name in names(cli_callers)) {
    got <- cli_failure(cli_callers[[name]], list(status = 1, stderr = stderr))
    expect_identical(
      cli_quoted_word(got$message),
      paste0("…", strrep("2", 1000)),
      info = name
    )
  }
})

test_that("a quoted text of exactly 1000 characters is not cut", {
  stderr <- strrep("3", 1000)
  for (name in names(cli_callers)) {
    got <- cli_failure(cli_callers[[name]], list(status = 1, stderr = stderr))
    expect_identical(cli_quoted_word(got$message), stderr, info = name)
  }
})

test_that("a cut inside a <xx> token drops the part of the token", {
  # After cleaning, the byte 0xff is the four characters "<ff>". With n
  # digits after it, the text is 4 + n characters long. For n from 997 to
  # 999, the cut keeps the last 3, 2, or 1 characters of the token, and all
  # of them are dropped.
  for (n in 997:999) {
    stderr <- paste0(bytes(0xff), strrep("4", n))
    for (name in names(cli_callers)) {
      got <- cli_failure(cli_callers[[name]], list(status = 1, stderr = stderr))
      expect_identical(
        cli_quoted_word(got$message),
        paste0("…", strrep("4", n)),
        info = paste(name, n)
      )
    }
  }
})
