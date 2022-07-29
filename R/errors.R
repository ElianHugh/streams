# ~~~~~~~~~~~~~~~ Generic errors ~~~~~~~~~~~~~~~~ #

pretty_stopifnot <- function(message, reason, condition) {
    if (isFALSE(condition)) {
        rlang::abort(
            c(
                message,
                x = reason
            ),
            call = NULL,
            class = construct_error("stopifnot")
        )
    }
}

error_unhandled_error_event <- function(err) {
    error <- construct_error("unhandled_error_event")
    err <- error_to_text(err)
    rlang::abort(
        c(
            err,
            "x" = "Error occured without an attached error handler",
            "i" = "Error events require error listeners to appropriately handle their errors"
        ),
        class = error
    )
}

# ~~~~~~~~~~~~~~~ Stream errors ~~~~~~~~~~~~~~~~ #

error_stream_closed <- function() {
    error <- construct_error("stream_already_closed")
    rlang::abort(
        c(
            x = "Attempted to manipulate stream after it has closed",
            "i" = "Streams can only be manipulated while they are in the 'started' state"
        ),
        class = error
    )
}


# ~~~~~~~~~~~~~~~ Internal ~~~~~~~~~~~~~~~ #

store_errors <- function() {
    stream_env$last_error <- rlang::trace_back(bottom = 1L)
}

error_to_text <- function(error) {
    if (rlang::is_error(error)) {
        error <- paste(
            error,
            collapse = "\n"
        )
    } else {
        error
    }
}

construct_error <- function(x) {
    sprintf("streams-%s-error", x)
}
