#' WriteableStream
#'
#' @description
#' An abstraction for writing streaming data.
#'
#' Data will be buffered in an internal queue before being
#' written to the underlying sink
#'
#' @details
#' Events:
#' - start
#' - error
#' - drain
#' - backpressure
#' - close
#'
#' @family streams
#' @export
WriteableStream <- R6::R6Class(
    "WriteableStream",
    inherit = EventEmitter,
    public = list(
        #' @description
        #' Create a new ReadableStream
        #' @param start a function that is called once the stream enters the "started" state
        #' @param write a function that is called whenever the stream attempts to write to the underlying source
        #' @param abort a function that is called to immediately abort the stream,
        #' dropping all unconsumed chunks in the process
        #' @param flush a function that is called prior to the stream ending
        #' @param queue_strategy a QueueStrategy object, describing how chunks will be buffered
        #' by the stream
        initialize = function(start = NULL,
                              write = NULL,
                              flush = NULL,
                              abort = NULL,
                              queue_strategy = NULL) {
            writeable_setup_default_stream(self, private, start, write, flush, abort, queue_strategy)
            invisible(self)
        },

        #' @description
        #' 1
        #' @param chunk data
        #' @return NULL
        write = function(chunk) writeable_write_to_queue(self, private, chunk),

        #' @description
        #' 1
        #' @return NULL
        abort = function() writeable_abort(self, private),

        #' @description
        #' 1
        #' @return NULL
        close = function() writeable_request_close(self, private),

        #' @description
        #' 1
        #' @param x 1
        #' @return NULL
        lock_stream = function(x) stream_set_downstream(self, private, x),

        #' @description
        #' 1
        #' @return NULL
        print = function() stream_print(self, private),

        #' @description
        #' 1
        #' @param ... 1
        #' @return NULL
        format = function(...) format_stream(self)
    ),
    active = list(
        #' @field current_state
        #' 1
        current_state = function() private$state,

        #' @field is_ready
        #' 1
        is_ready = function() writeable_is_ready(self, private),

        #' @field is_locked
        #' 1
        is_locked = function() private$locked,

        #' @field controller
        #' 1
        controller = function() writeable_get_controller(self, private),

        #' @field desired_size
        #' 1
        desired_size = function() stream_get_desired_size(private)
    ),
    private = list(
        # streams
        upstream = NULL,
        downstream = NULL,

        # state
        backpressure = NULL,
        writing_to_sink = NULL,
        write_algorithm = NULL,
        stored_error = NULL,
        queue = NULL,
        queue_strategy = NULL,
        locked = NULL,
        close_requested = NULL,
        state = NULL,
        started = NULL,
        start_result = NULL,

        # algorithms
        desired_size_algorithm = NULL,
        start_algorithm = NULL,
        flush_algorithm = NULL,
        abort_algorithm = NULL,
        abort_method = NULL,
        close_method = NULL,
        finalize = function() {
            if (!rlang::is_interactive()) {
                writeable_keep_open(self, private)
            }
            self$abort()
        }
    ),
    cloneable = FALSE
)


# ~~~ state ~~~~~~~~~~~~~

writeable_is_ready <- function(self, private) {
    if (private$backpressure || private$writing_to_sink) {
        return(FALSE)
    }
    self$desired_size > 0L
}

writeable_closing_or_closed <- function(private) {
    private$state == "closed" || private$close_requested
}

# ~~~ operations ~~~~~~~~

writeable_setup_default_stream <- function(self, private, start, write, flush, abort, queue_strategy) {
    # create queue
    private$queue <- Queue$new()
    private$queue_strategy <- queue_strategy %||% object_length_strategy

    # set algorithms
    private$start_algorithm <- start %||% no_op_function
    private$write_algorithm <- write %||% no_op_function
    private$flush_algorithm <- flush %||% no_op_function
    private$abort_algorithm <- abort %||% no_op_function
    private$desired_size_algorithm <- function() private$queue_strategy$highwater_mark - private$queue$size

    # set state
    private$locked <- FALSE
    private$started <- FALSE
    private$close_requested <- FALSE
    private$backpressure <- FALSE
    private$writing_to_sink <- FALSE
    private$state <- "starting"

    self$prepend_listener(
        internal_events$stream_error, function(e) {
            private$state <- "errored"
            private$stored_error <- e
            self$emit("error", e)
        }
    )

    self$prepend_listener("pipe", function(destination) stream_set_upstream(self, private, destination))

    prototype_promise_then(
        writeable_start(self, private),
        function(v) {
            private$start_result <- v
            self$emit("start")
        },
        function(e) writeable_error(self, private, e)
    )
}

writeable_get_controller <- function(self, private) {
    list(
        emit = self$emit,
        desired_size = self$desired_size,
        start_value = private$start_result,
        close = self$close,
        abort = self$abort,
        error = function(e) writeable_error(self, private, e)
    )
}

writeable_enqueue <- function(self, private, chunk) {
    tryCatch(
        expr = {
            private$queue$add(chunk)
        }, error = function(e) writeable_error(self, private, e)
    )

    if (!writeable_closing_or_closed(private)) {
        stream_update_backpressure(self, private)
    }

    writeable_advance_queue(self, private)
}

writeable_advance_queue <- function(self, private) {
    if (private$state == "errored") {
        # handle erroring
        return()
    }

    if (!private$started ||
        private$writing_to_sink ||
        private$queue$size == 0L) {
        return()
    }

    chunk_value <- peek_next_value(private)
    # check if is close sentinel (NYI)
    if (FALSE) {
        # do something
    } else {
        writeable_write_to_sink(self, private, chunk_value)
    }
}

writeable_write_to_queue <- function(self, private, chunk) {
    if (stream_is_errored_or_closed(self)) {
        error_stream_closed()
    } else {
        invisible(writeable_enqueue(self, private, chunk))
    }
}

writeable_write_to_sink <- function(self, private, chunk) {
    if (!private$writing_to_sink) {
        private$writing_to_sink <- TRUE # prevent reentrance
        prototype_promise_then(
            private$write_algorithm(chunk, self$controller),
            function(v) {
                private$writing_to_sink <- FALSE
                dequeue_value(private)
                if (!writeable_closing_or_closed(private)) {
                    stream_update_backpressure(self, private)
                }
                writeable_advance_queue(self, private)

                if (private$close_requested && stream_is_empty_forever(self, private)) {
                    async_call(~ writeable_close(self, private))
                }
            },
            function(e) writeable_error(self, private, e)
        )
    }
}

writeable_start <- function(self, private) {
    private$started <- TRUE
    private$state <- "started"
    private$start_algorithm(self$controller)
}

writeable_error <- function(self, private, error) {
    if (private$state != "errored") {
        store_errors()
        private$queue$reset()
        self$emit(internal_events$stream_error, error)
    }
}

writeable_request_close <- function(self, private) {
    private$close_requested <- TRUE
    if (stream_is_empty_forever(self, private)) {
        writeable_close(self, private)
    }
}

writeable_close <- function(self, private) {
    if (!stream_is_errored_or_closed(self)) {
        prototype_promise_then(
            private$flush_algorithm(self$controller),
            function(v) {
                private$state <- "closed"
                private$queue$reset()
                writeable_clear_algorithms(private)
                self$emit("close")
                self$remove_all_listeners()
            },
            function(e) {} # nolint
        )
    }
}

writeable_abort <- function(self, private) {
    if (!stream_is_errored_or_closed(self)) {
        writeable_close(self, private)
        prototype_promise_then(
            private$abort_algorithm(self$controller),
            function(v) {}, # nolint
            function(e) writeable_error(self, private, e)
        )
    }
}

writeable_clear_algorithms <- function(private) {
    private$start_algorithm <- NULL
    private$write_algorithm <- NULL
    private$desired_size_algorithm <- NULL
}

writeable_update_backpressure <- function(self, private) {
    new_backpressure <- self$desired_size <= 0L
    if (private$backpressure != new_backpressure) {
        if (!new_backpressure) {
            self$emit("drain")
        } else {
            self$emit("backpressure")
        }
    }
    private$backpressure <- new_backpressure
}

# this is to get around a limitation with the current async implementation
# we wait for the stream to be finished in some way before allowing the session to close
writeable_keep_open <- function(self, private) {
        while (
            !stream_is_errored_or_closed(self) &&
            (writeable_has_ready_downstream(private) && (private$queue$size > 0L ||
                writeable_has_ready_upstream(private)))
        ) {
            later::run_now(loop = stream_env$stream_loop)
        }
    self$close()
}

writeable_has_ready_upstream <- function(private) {
    !is.null(private$upstream) && any(private$upstream$is_ready)
}

writeable_has_ready_downstream <- function(private) {
    !is.null(private$downstream) && any(private$downstream$is_ready)
}