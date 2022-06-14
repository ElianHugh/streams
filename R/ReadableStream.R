#' ReadableStream
#'
#' @description
#' An abstraction for reading streaming data.
#'
#' When retrieved from an underlying source,
#' data will be buffered in an internal queue.
#'
#' Data can be consumed by either attaching a "data"
#' listener, piping, or teeing the stream.
#'
#' @details
#'
#' Events:
#' - start
#' - error
#' - data
#' - pipe
#' - tee
#' - close
#'
#' @family streams
#' @seealso readable_controller
#' @export
ReadableStream <- R6::R6Class(
    inherit = EventEmitter,
    "ReadableStream",
    public = list(
        #' @description
        #' Create a new ReadableStream
        #' @eval docs_start_fn()
        #' @eval docs_pull_fn()
        #' @eval docs_flush_fn()
        #' @eval docs_abort_fn()
        #' @eval docs_queue_obj()
        initialize = function(start = NULL,
                              pull = NULL,
                              flush = NULL,
                              abort = NULL,
                              queue_strategy = NULL) {
            readable_setup_default_stream(
                self,
                private,
                start,
                pull,
                flush,
                abort,
                queue_strategy
            )
            invisible(self)
        },

        #' @description
        #' Pipe the ReadableStream to a WriteableStream.
        #' Pulled data from the ReadableStream is written to the WriteableStream,
        #' respecting backpressure signals from the WriteableStream.
        #'
        #' When piped, the ReadableStream is in a locked state, and cannot
        #' be manually controlled.
        #'
        #' Specifics:
        #' - Upon calling pipe(), the ReadableStream emits a "pipe" event.
        #' - Data events will cause the ReadableStream to write to the WriteableStream
        #' - The ReadableStream listens to the WriteableStream's drain and backpressure events,
        #' pausing and resuming flow when appropriate
        #' - When a "close" event is emitted from the ReadableStream,
        #' the WriteableStream is sent a close request
        #' - When an "error" event is emitted from the ReadableStream,
        #' it is propogated to the WriteableStream.
        #'
        #' @param destination ReadableStream
        #' @return destination
        pipe = function(destination) readable_pipe(self, private, destination),

        #' @description
        #' Tee the ReadableStream, creating two ReadableStreams in the process.
        #' Data from this ReadableStream will flow into the two destination streams,
        #' and will respect backpressure signals from both destination streams.
        #'
        #' Specifics:
        #' - Upon calling tee(), the ReadableStream will emit a "tee" event.
        #' - The resulting teed streams act as push streams, wherein the data from the
        #' teeing stream is pushed when appropriate
        #' - Data is only pushed when both streams are able to accept new chunks,
        #' otherwise the chunks will be buffered inside the teeing stream
        #' - The queue strategy of the teeing stream is respected
        #' - The teed streams utilise the default queue strategy, accepting one chunk at a time
        #'
        #' @return list of teed streams
        tee = function() readable_tee(self, private),

        #' @description
        #' 1
        #' @param reason data
        #' @return NULL
        abort = function(reason = NULL) readable_abort(self, private),

        #' @description
        #' 1
        #' @return NULL
        close = function() readable_request_close(self, private),

        #' @description
        #' 1
        #' @param destination 1
        #' @return NULL
        lock_stream = function(destination) stream_set_downstream(self, private, destination),

        #' @description
        #' 1
        #' @param destination 1
        #' @return NULL
        set_upstream = function(destination) stream_set_upstream(self, private, destination),

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

        #' @field is_locked
        #' 1
        is_locked = function() private$locked,

        #' @field is_ready
        #' A boolean value of whether the stream is ready to accept chunks.
        #' This does not, however, mean that the stream is *able* to accept chunks
        #' (e.g. if it has a full buffer).
        is_ready = function() readable_is_ready(private),

        #' @field controller
        #' A list that is passed to start, pull, and abort methods. Contains references to the following:
        #'
        #' - emit
        #' - desired_size
        #' - start_value
        #' - enqueue
        #' - close
        controller = function() readable_get_controller(self, private),

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
        pulling_from_source = NULL,
        pull_again_from_source = NULL,
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
        pull_algorithm = NULL,
        cancel_algorithm = NULL,
        start_algorithm = NULL,
        flush_algorithm = NULL,
        abort_algorithm = NULL,
        abort_method = NULL,
        close_method = NULL,
        finalize = function() {
            if (!rlang::is_interactive()) {
                readable_keep_open(self, private)
            }
            self$abort()
        }
    ),
    cloneable = TRUE
)

# ~~~ state ~~~~~~~~~~~~~

readable_is_ready <- function(private) {
    !private$close_requested && private$state == "started"
}

readable_can_output <- function(self, private) {
    if (stream_is_errored_or_closed(self)) {
        return(FALSE)
    }

    listeners <- self$listener_count("data")

    if (self$is_locked) {
        backpressure <- lapply(private$downstream, function(stream) {
            !stream_is_errored_or_closed(stream)
        })
        any(unlist(backpressure))
    } else {
        listeners > 0L
    }
}

readable_can_pull_from_source <- function(self, private) {
    if (!readable_is_ready(private)) {
        return(FALSE)
    }
    stream_get_desired_size(private) > 0L
}

readable_can_pull_from_queue <- function(self, private) {
    private$queue$size > 0L && readable_can_output(self, private)
}

# ~~~ operations ~~~~~~~~

readable_setup_default_stream <- function(self, private, start, pull, flush, abort, queue_strategy) {
    # create queue
    private$queue <- Queue$new()
    private$queue_strategy <- queue_strategy %||% object_length_strategy

    # set algorithms
    private$start_algorithm <- start %||% no_op_function
    private$pull_algorithm <- pull %||% no_op_function
    private$abort_algorithm <- abort %||% no_op_function
    private$flush_algorithm <- flush %||% no_op_function
    private$desired_size_algorithm <- function() private$queue_strategy$highwater_mark - private$queue$size

    # set state
    private$locked <- FALSE
    private$backpressure <- FALSE
    private$started <- FALSE
    private$close_requested <- FALSE
    private$pulling_from_source <- FALSE
    private$pull_again_from_source <- FALSE
    private$state <- "starting"

    self$prepend_listener(
        internal_events$stream_error, function(e) {
            private$state <- "errored"
            private$stored_error <- e
            self$emit("error", e)
            readable_clear_algorithms(private)
            self$remove_all_listeners()
        }
    )

    self$prepend_listener(
        "new_listener",
        function(event_name, ...) {
            if (event_name == "data" && length(self$raw_listeners("data")) == 0L) {
                async_call(~ readable_pull_from_queue(self, private))
            }
        }
    )

    start_res <- readable_start(self, private)
    prototype_promise_then(
        start_res,
        function(v) {
            private$start_result <- v
            self$emit("start")
            async_call(~ readable_pull_from_source(self, private))
        },
        function(e) readable_error(self, private, e)
    )
}

readable_get_controller <- function(self, private) {
    list(
        emit = self$emit,
        desired_size = self$desired_size,
        start_value = private$start_result,
        enqueue = function(chunk) readable_enqueue(self, private, chunk),
        close = self$close,
        abort = self$abort,
        error = function(e) readable_error(self, private, e)
    )
}

readable_enqueue <- function(self, private, chunk) {
    if (readable_is_ready(private)) {
        tryCatch(
            expr = {
                private$queue$add(chunk)
                async_call(~ readable_pull_from_source(self, private))
            }, error = function(e) readable_error(self, private, e)
        )
    }

    if (!stream_is_closing_or_closed(self, private)) {
        stream_update_backpressure(self, private)
    }
}

readable_advance_queue <- function(self, private) {
    if (readable_can_pull_from_queue(self, private)) {
        peeked_value <- peek_next_value(private)
        if (!is.null(private$downstream)) {
            ready <- all(unlist(
                lapply(private$downstream, function(stream) {
                    stream$is_ready
                })
            ))
            if (!ready) {
                return()
            }
        }
        dequeue_value(private)
        if (!stream_is_closing_or_closed(self, private)) {
            stream_update_backpressure(self, private)
        }

        self$emit("data", peeked_value)
    }
}

readable_pull_from_source <- function(self, private) {
    should_pull_from_source <- readable_can_pull_from_source(self, private)
    if (should_pull_from_source) {
        if (private$pulling_from_source) {
            private$pull_again_from_source <- TRUE
            return(invisible(NULL))
        }

        if (private$pull_again_from_source) {
            return(invisible(NULL))
        }

        private$pulling_from_source <- TRUE

        prototype_promise_then(
            private$pull_algorithm(self$controller),
            function(v) {
                private$pulling_from_source <- FALSE
                if (private$pull_again_from_source) {
                    private$pull_again_from_source <- FALSE
                    async_call(~ readable_pull_from_source(self, private))
                }

                async_call(~ readable_pull_from_queue(self, private))
            },
            function(e) readable_error(self, private, e)
        )
    }

    if (readable_can_pull_from_queue(self, private)) {
        async_call(~ readable_pull_from_queue(self, private))
    }
}

readable_pull_from_queue <- function(self, private) {
    if (readable_can_pull_from_queue(self, private)) {
        readable_advance_queue(self, private)
        if (private$close_requested &&
            stream_is_empty_forever(self, private)) {
            return(
                readable_close(self, private)
            )
        }
    }

    if (readable_is_ready(private)) {
        async_call(~ readable_pull_from_source(self, private))
    } else if (readable_can_pull_from_queue(self, private)) {
        async_call(~ readable_pull_from_queue(self, private))
    }
}

readable_pipe <- function(self, private, destination) {
    self$lock_stream(destination)

    if (destination$desired_size < 1L) {
        private$state <- "waiting"
    }

    destination$on("drain", function() {
        private$state <- "started"
        async_call(~ readable_pull_from_source(self, private))
    })
    destination$on("backpressure", function() {
        private$state <- "waiting"
    })

    # destination listeners

    destination$prepend_listener(internal_events$stream_error, function(e) {
        self$abort(e)
    })

    # self listeners
    self$on("data", function(chunk) {
        destination$write(chunk)
    })
    self$on("error", function(error) {
        destination$emit(internal_events$stream_error, error)
    })
    self$on("close", function() {
        destination$close()
    })

    destination$emit("pipe", self)
    invisible(destination)
}

readable_tee <- function(self, private) {
    closed_tees <- 0L
    drains <- 0L
    close_tees <- function(...) {
        closed_tees <<- closed_tees + 1L
        if (closed_tees == 2L) {
            self$close()
        }
    }
    watch_drains <- function(add = TRUE) {
        if (add) {
            drains <<- drains + 1L
        } else {
            drains <<- drains - 1L
        }
    }

    left_branch <- ReadableStream$new(
        start = NULL,
        pull = NULL,
        abort = close_tees
        # queue_strategy is default
    )

    right_branch <- ReadableStream$new(
        start = NULL,
        pull = NULL,
        abort = close_tees
        # queue_strategy is default
    )

    private$locked <- TRUE

    self$on("close", function() {
        left_branch$close()
        right_branch$close()
    })

    lapply(
        c(left_branch, right_branch),
        function(branch) {
            stream_set_downstream(self, private, branch)
            self$on("data", function(chunk) {
                if (branch$current_state != "closed") {
                    branch$controller$enqueue(chunk)
                }
            })
            self$on("error", function(error) {
                branch$emit(internal_events$stream_error, error)
            })

            branch$on("drain", function() {
                watch_drains(FALSE)
                if (drains < 1L) {
                    private$state <- "started"
                    async_call(~ readable_pull_from_source(self, private))
                }
            })
            branch$on("backpressure", function() {
                watch_drains(TRUE)
                if (private$state != "waiting") {
                    private$state <- "waiting"
                }
            })

            branch$on("close", function() {
                stream_remove_downstream(private, branch)
                if (private$state == "waiting") {
                    watch_drains(FALSE)
                    if (drains < 1L) {
                        private$state <- "started"
                        async_call(~ readable_pull_from_source(self, private))
                    }
                }
            })
        }
    )

    self$emit("tee")
    invisible(private$downstream)
}

readable_start <- function(self, private) {
    if (!private$started) {
        private$started <- TRUE
        private$state <- "started"
        private$start_algorithm(self$controller)
    }
}

readable_error <- function(self, private, error) {
    if (private$state != "errored") {
        private$queue$reset()
        self$emit(internal_events$stream_error, error)
    }
}

readable_request_close <- function(self, private) {
    private$close_requested <- TRUE
    if (stream_is_empty_forever(self, private)) {
        readable_close(self, private)
    }
}

readable_close <- function(self, private) {
    if (!stream_is_errored_or_closed(self)) {
        prototype_promise_then(
            private$flush_algorithm(self$controller),
            function(v) {
                private$state <- "closed"
                private$queue$reset()
                readable_clear_algorithms(private)
                self$emit("close")
                self$remove_all_listeners()
            },
            function(e) readable_error(self, private, e)
        )
    }
}

readable_abort <- function(self, private) {
    if (!stream_is_errored_or_closed(self)) {
        readable_close(self, private)
        prototype_promise_then(
            private$abort_algorithm(self$controller),
            function(v) {}, # nolint
            function(e) readable_error(self, private, e)
        )
    }
}

readable_clear_algorithms <- function(private) {
    private$start_algorithm <- NULL
    private$pull_algorithm <- NULL
    private$desired_size_algorithm <- NULL
}

readable_update_backpressure <- function(self, private) {
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
readable_keep_open <- function(self, private) {
    while (
        !stream_is_errored_or_closed(self) && (
        readable_can_output(self, private) ||
        (readable_can_pull_from_source(self, private)))) {
            later::run_now(loop = stream_env$stream_loop)
        }
    self$close()
}