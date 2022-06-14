wait_for_async <- function() {
    skip_if_not_installed("later")
    while (!later::loop_empty(loop = later::global_loop()) || !later::loop_empty(loop = streams:::stream_env$stream_loop)) {
        later::run_now()
        Sys.sleep(0.00001)
    }
}

await_stream_end <- function(stream) {
    promise_once(stream, "close")
    wait_for_async()
}

expect_object_length <- function(x, len, stream) {
    await_stream_end(stream)
    testthat::expect_length(x, len)
}

expect_stream_state <- function(state, stream) {
    testthat::expect_equal(stream$current_state, state)
}

expect_queue_size <- function(size, stream) {
  testthat::expect_equal(stream$.__enclos_env__$private$queue$size, size)
}

expect_stream_error_text <- function(error, stream) {
    testthat::expect_identical(error, stream$.__enclos_env__$private$stored_error)
}

cleanup_stream <- function(stream) {
    stream$abort()
    rm(stream)
}