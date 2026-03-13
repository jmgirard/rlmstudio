#' Get the absolute path to the LMS executable
#' @noRd
get_lms_path <- function() {
  # 1. Allow an explicit override via environment variable
  custom_path <- Sys.getenv("RLMSTUDIO_LMS_PATH")
  if (custom_path != "" && file.exists(custom_path)) {
    return(custom_path)
  }

  # 2. Check the standard system PATH
  cmd <- Sys.which("lms")
  if (cmd != "") {
    return(unname(cmd))
  }

  # 3. Fallback to checking common installation directories
  os <- Sys.info()[["sysname"]]
  home <- Sys.getenv("HOME")

  common_paths <- if (os == "Windows") {
    c(file.path(Sys.getenv("LOCALAPPDATA"), "LM-Studio", "bin", "lms.exe"))
  } else {
    c(
      file.path(home, ".cache", "lm-studio", "bin", "lms"),
      file.path(home, ".local", "bin", "lms")
    )
  }

  for (p in common_paths) {
    if (file.exists(p)) {
      return(p)
    }
  }

  # 4. Abort if all checks fail
  cli::cli_abort(c(
    "x" = "The LM Studio CLI ({.val lms}) was not found on your system.",
    "i" = "Please install it or run {.fun install_lmstudio} to configure your environment."
  ))
}
