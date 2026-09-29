# The abort of a failed CLI run quotes the CLI text. Each function that runs
# the CLI and aborts on its exit code runs over the same texts here. cli wraps
# long bullets, so messages are compared after each whitespace run is
# collapsed to one space.

cli_squish <- function(x) gsub("\\s+", " ", trimws(x))

# Each entry runs one function so that it reaches its failure branch.
cli_callers <- list(
  lms_server_start = function() lms_server_start(wait = 0),
  lms_server_stop = function() lms_server_stop(),
  lms_daemon_start = function() lms_daemon_start(),
  lms_daemon_stop = function() lms_daemon_stop()
)

# The first sentence of each abort.
cli_whats <- c(
  lms_server_start = "Failed to start the LM Studio server.",
  lms_server_stop = "Failed to stop the LM Studio server.",
  lms_daemon_start = "Failed to start the LM Studio daemon.",
  lms_daemon_stop = "Failed to stop the LM Studio daemon."
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

test_that("a failed run gives the exit code and quotes stderr first", {
  cases <- list(
    stderr = list(
      res = list(stdout = "", stderr = "from stderr\n"),
      said = "from stderr"
    ),
    stdout = list(
      res = list(stdout = "from stdout\n", stderr = ""),
      said = "from stdout"
    ),
    both = list(
      res = list(stdout = "from stdout", stderr = "from stderr"),
      said = "from stderr"
    ),
    blank_stderr = list(
      res = list(stdout = "from stdout", stderr = " \n\u00a0"),
      said = "from stdout"
    )
  )
  for (name in names(cli_callers)) {
    for (case in names(cases)) {
      res <- c(list(status = 2L), cases[[case]]$res)
      got <- cli_failure(cli_callers[[name]], res)
      label <- paste(name, case)
      expect_true(
        grepl(
          paste(cli_whats[[name]], "Exit code: 2."),
          got$message,
          fixed = TRUE
        ),
        label = label
      )
      expect_cli_said(got$message, cases[[case]]$said, label)
      if (case == "both") {
        expect_false(
          grepl("from stdout", got$message, fixed = TRUE),
          label = label
        )
      }
    }
  }
})

test_that("a failed run with no text gives the exit code alone", {
  empties <- list(
    list(status = 1L),
    list(status = 1L, stdout = NULL, stderr = NULL),
    list(status = 1L, stdout = NA_character_, stderr = NA_character_),
    list(status = 1L, stdout = "\f\u00a0", stderr = " \n\t")
  )
  for (name in names(cli_callers)) {
    for (res in empties) {
      got <- cli_failure(cli_callers[[name]], res)
      expect_true(
        grepl(
          paste(cli_whats[[name]], "Exit code: 1."),
          got$message,
          fixed = TRUE
        ),
        label = name
      )
      expect_false(
        grepl("The CLI said", got$message, fixed = TRUE),
        label = name
      )
    }
  }
})

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
  # link closed by ESC \ or by BEL. Then the forms that cli::ansi_strip()
  # leaves: the cursor save and restore codes ESC 7 and ESC 8, a character
  # set code, a window title closed by BEL or by ESC \, and a lone ESC.
  texts <- c(
    color = "\033[31mred\033[39m done",
    cursor = "\033[?25lhide\033[2K\033[1Gline done",
    link_st = "\033]8;;https://lmstudio.ai\033\\link\033]8;;\033\\ done",
    link_bel = "\033]8;;https://lmstudio.ai\alink\033]8;;\a done",
    save_restore = "\0337saved\0338 done",
    charset = "\033(Bplain done",
    title_bel = "\033]0;lmstudio.ai\anamed done",
    title_st = "\033]0;lmstudio.ai\033\\named done",
    lone = "lone done\033"
  )
  expected <- c(
    color = "red done",
    cursor = "hideline done",
    link_st = "link done",
    link_bel = "link done",
    save_restore = "saved done",
    charset = "plain done",
    title_bel = "named done",
    title_st = "named done",
    lone = "lone done"
  )
  for (name in names(cli_callers)) {
    for (form in names(texts)) {
      got <- cli_failure(
        cli_callers[[name]],
        list(status = 1, stderr = texts[[form]])
      )
      expect_cli_said(got$message, expected[[form]], paste(name, form))
      expect_false(grepl("\033", got$message, fixed = TRUE), label = form)
      expect_false(
        grepl("lmstudio.ai", got$message, fixed = TRUE),
        label = form
      )
    }
  }
})

test_that("each whitespace run in the quoted text becomes one space", {
  # cli prints a run of spaces inside a bullet as one space, so this test
  # cannot see how a non-breaking space inside a text is read. The blank
  # stderr case and the no-text cases above hold one, and they fail if it
  # does not count as whitespace.
  stderr <- "line one\n\tline two\u00a0\u00a0end\r\n  "
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

# The stop exits. A stop whose CLI text says that nothing runs is a no-op
# with an info message, not an abort.

# Run `code` against a CLI that returns `res`, with the quiet option off.
stop_exit <- function(code, res) {
  withr::local_options(rlmstudio.quiet = FALSE)
  local_mocked_bindings(lms_path = function() "lms")
  local_mocked_bindings(run = function(...) res, .package = "processx")
  value <- NULL
  shown <- capture_shown(value <- withVisible(code))
  c(shown, list(value = value))
}

# Recorded from `lms server stop` with no server running, on 2026-09-29. It
# exited 1.
server_not_running <- "Error: The server is not running.\n"

test_that("lms_server_stop is a no-op when no server runs", {
  texts <- c(
    recorded = server_not_running,
    bad_byte = paste0("Error: The server is not running. ", bytes(0xff), "\n"),
    far = paste0("Error: The server is NOT RUNNING. ", strrep("5", 1500))
  )
  for (name in names(texts)) {
    got <- stop_exit(
      lms_server_stop(),
      list(status = 1L, stdout = "", stderr = texts[[name]])
    )
    expect_null(got$error)
    expect_match(
      got$messages,
      "server is already stopped",
      fixed = TRUE,
      info = name
    )
    expect_identical(got$value, list(value = 1L, visible = FALSE), info = name)
  }
})

test_that("lms_daemon_stop keeps running when the GUI manages the daemon", {
  texts <- c(
    plain = "Error: this daemon is part of LM Studio.",
    upper = "PART OF LM STUDIO",
    bad_byte = paste0("part of LM Studio ", bytes(0xff)),
    far = paste0("part of LM Studio ", strrep("6", 1500)),
    # With both phrases, the GUI phrase wins.
    both = "not running, and part of LM Studio"
  )
  for (name in names(texts)) {
    got <- stop_exit(
      lms_daemon_stop(),
      list(status = 1L, stdout = "", stderr = texts[[name]])
    )
    expect_null(got$error)
    expect_match(
      got$messages,
      "managed by the LM Studio GUI",
      fixed = TRUE,
      info = name
    )
    expect_identical(
      got$value,
      list(value = FALSE, visible = FALSE),
      info = name
    )
  }
})

test_that("lms_daemon_stop is a no-op when no daemon runs", {
  texts <- c(
    plain = "The daemon is not running.",
    mixed = "The daemon is Not Running.",
    bad_byte = paste0("not running ", bytes(0xff)),
    far = paste0("not running ", strrep("7", 1500)),
    stdout_only = NA_character_
  )
  for (name in names(texts)) {
    res <- list(status = 1L, stdout = "", stderr = texts[[name]])
    if (name == "stdout_only") {
      res <- list(status = 1L, stdout = "not running\n", stderr = "")
    }
    got <- stop_exit(lms_daemon_stop(), res)
    expect_null(got$error)
    expect_match(
      got$messages,
      "daemon is already stopped",
      fixed = TRUE,
      info = name
    )
    expect_identical(
      got$value,
      list(value = TRUE, visible = FALSE),
      info = name
    )
  }
})

test_that("the lms_daemon_stop abort keeps its hint about force", {
  got <- cli_failure(
    function() lms_daemon_stop(),
    list(status = 1L, stdout = "", stderr = "some other fault")
  )
  expect_cli_said(got$message, "some other fault", "lms_daemon_stop")
  expect_match(got$message, "lms_daemon_stop(force = TRUE)", fixed = TRUE)
  expect_match(got$message, "lms_server_stop()", fixed = TRUE)
})

test_that("lms_daemon_stop(force = TRUE) says when no server runs", {
  withr::local_options(rlmstudio.quiet = FALSE)
  local_mocked_bindings(lms_path = function() "lms")
  local_mocked_bindings(
    run = function(command, args, ...) {
      if (identical(args, c("server", "stop"))) {
        list(status = 1L, stdout = "", stderr = server_not_running)
      } else {
        list(status = 0L, stdout = "", stderr = "")
      }
    },
    .package = "processx"
  )
  shown <- capture_shown(value <- lms_daemon_stop(force = TRUE))
  expect_null(shown$error)
  expect_true(value)
  expect_match(shown$messages, "server is already stopped", fixed = TRUE)
  expect_match(shown$messages, "daemon stopped successfully", fixed = TRUE)
})
