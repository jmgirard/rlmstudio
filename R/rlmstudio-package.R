#' @keywords internal
#' @section Options:
#' \itemize{
#'   \item \code{rlmstudio.quiet}: A logical value. If \code{TRUE}, suppresses informational console messages and progress bars across the package. Defaults to \code{FALSE}. The \code{quiet} argument of [list_models()], [list_instances()], [lms_chat_batch()], and [lms_embed()] defaults to \code{NULL}, which follows this option. \code{quiet = TRUE} hides the output of that function, and \code{quiet = FALSE} shows it, also when this option is \code{TRUE}. The option does not change the \code{quiet} argument of [lms_server_status()], which passes \code{--quiet} to the \code{lms} CLI.
#' }
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
