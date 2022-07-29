# ~~~~~~~~~~~ fns ~~~~~~~~~~~~~~~~~~

dequeue_value <- function(private) {
    queue <- private$queue
    if (!is.null(queue) && queue$size > 0L) {
        queue$remove()
    } else {
        NULL
    }
}

peek_next_value <- function(private) {
    queue <- private$queue
    if (queue$size > 0L) {
        queue$peek()
    } else {
        NULL
    }
}

no_op_function <- function(...) {
    # do nothing
}

prototype_promise_then <- function(object, fulfill, reject) {
    if (inherits(object, "promise") && !inherits(object, "AsIs")) {
        object$then(
            onFulfilled = fulfill,
            onRejected = function(...) {
                reject(...)
            }
        )
    } else {
        tryCatch(
            expr = {
                fulfill(object)
            },
            error = function(e) {
                reject(e)
            }
        )
    }
}

to_function <- function(fn, ...) {
    if (!missing(...)) {
        func <- fn
        fn <- function() {
            func(...)
        }
    } else if (rlang::is_formula(fn)) {
        fn <- rlang::as_function(fn)
    }
    fn
}

# ~~~~ condition checks ~~~~~~~~~~~~~~~~~~~~~~~~~ #

`%nin%` <- Negate(`%in%`)

is_truthy <- function(x) {
    return(
        any(!is.null(x)) &&
            any(!is.na(x)) &&
            any(!inherits(x, "try-error")) &&
            length(x) > 0L &&
            any(nzchar(x))
    )
}

is_falsey <- Negate(is_truthy)

`%||%` <- rlang::`%||%`

# ~~~~~ list manipulation ~~~~~~~~~~~~~~~~~

splice_element <- function(array, element) {
    Filter(
        function(x) !identical(x, element),
        array
    )
}

prepend <- function(x, values) {
    append(x, values, 0L)
}


# ~~~~~~~~~~~~~ enums ~~~~~~~~~~~~~~~~~~~~~~~

internal_events <- list(
    stream_error = ".STREAMSpkg_INTERNAL_STREAM_ERROR",
    tee_error    = ".STREAMSpkg_INTERNAL_TEE_ERROR",
    pipe_error   = ".STREAMSpkg_INTERNAL_PIPE_ERROR"
)
