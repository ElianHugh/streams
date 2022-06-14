async_call <- function(...) {
    later::later(
        ...,
        delay = 0L,
        loop = stream_env$stream_loop
    )
}

no_pending_operations <- function() {
    later::loop_empty(later::global_loop()) && later::loop_empty(stream_env$stream_loop)
}