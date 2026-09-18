#' Error conditions raised by rlmstudio
#'
#' The functions in this package that talk to the LM Studio REST API raise two
#' condition classes of their own. Both are raised through [cli::cli_abort()],
#' so each one is an R error that you can catch by class with
#' [base::tryCatch()].
#'
#' @section Server not running:
#' Functions that call the LM Studio REST API check that a server answers at
#' the `host` address. A condition of class `rlmstudio_no_server` is raised
#' when the LM Studio server is not running. Start the server with
#' [lms_server_start()], or give `host` the address that your server listens
#' on.
#'
#' @section API failure:
#' A condition of class `rlmstudio_api_error` is raised when a REST call
#' returns a response that the wrapper treats as a failure. The condition
#' carries a `status` field, which holds the HTTP response status as an
#' integer.
#'
#' @name rlmstudio-conditions
#'
#' @examples
#' \dontrun{
#' tryCatch(
#'   list_models(host = "http://localhost:9999"),
#'   rlmstudio_no_server = function(cnd) {
#'     message("The server is not running: ", conditionMessage(cnd))
#'   },
#'   rlmstudio_api_error = function(cnd) {
#'     message("The API call failed with status ", cnd$status)
#'   }
#' )
#' }
NULL
