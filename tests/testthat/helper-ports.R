# Ports for the tests that need a real TCP socket. The scan starts at a point
# set by the process id and walks forward, so it never calls the random number
# generator: sample() would move .Random.seed for every later test, and under a
# fixed seed it would try the same ports on every run. Two R processes start at
# different points. A port in use makes serverSocket() raise, so the scan moves
# on to the next one.

# Bind the first free port in `ports` and return the open connection with its
# port. After 50 tries, stop with the range that was scanned.
bind_free_port <- function(ports) {
  start <- Sys.getpid() %% length(ports)
  for (i in seq_len(min(50, length(ports)))) {
    port <- ports[(start + i - 1) %% length(ports) + 1]
    con <- tryCatch(serverSocket(port), error = function(e) NULL)
    if (!is.null(con)) {
      return(list(con = con, port = port))
    }
  }
  stop("No free port in ", min(ports), "-", max(ports), ".", call. = FALSE)
}

# Open a listening socket and return its port. The socket closes when `env`
# exits, by default the calling test.
local_listener <- function(ports = 20000:40000, env = parent.frame()) {
  bound <- bind_free_port(ports)
  withr::defer(close(bound$con), envir = env)
  bound$port
}

# Return a port that nothing listens on. The helper binds it and gives it back,
# so the port was free a moment ago.
free_port <- function(ports = 20000:40000) {
  bound <- bind_free_port(ports)
  close(bound$con)
  bound$port
}
