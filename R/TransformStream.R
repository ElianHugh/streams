#' Transform Stream
#'
#' @description
#'
#' An entangled pair of readable and writeable streams, wherein writing to the
#' stream causes a transform function that can enqueue chunks to the readable
#' side.
#'
#' @details
#'
#' Events:
#' - start
#' - error
#' - data
#' - drain
#' - backpressure
#' - pipe
#' - tee
#' - close
#'
#' @examples
#' # All the functional streams are implemented using
#' # the transform stream class
#' # For instance, `streams::map_stream`:
#'
#' map_stream <- function(fn, ...) {
#'     fn <- to_function(fn)
#'     TransformStream$new(
#'         transform = function(chunk, controller) {
#'             res <- fn(chunk)
#'             controller$enqueue(res)
#'         },
#'         ...
#'     )
#' }
#'
#' # Or `streams::filter_stream`
#'
#' filter_stream <- function(fn, ...) {
#'     fn <- to_function(fn)
#'     TransformStream$new(
#'         transform = function(chunk, controller) {
#'             res <- isTRUE(fn(chunk))
#'             if (res) {
#'                 controller$enqueue(chunk)
#'             }
#'         },
#'         ...
#'     )
#' }
#'
#' @family streams
#' @export
TransformStream <- R6::R6Class(
    "TransformStream",
    inherit = EventEmitter,
    public = list(
        #' @description
        #' 1
        #' @param start 1
        #' @param transform 1
        #' @param flush 1
        #' @param writeable_strategy 1
        #' @param readable_strategy 1
        #' @return NULL
        initialize = function(start = NULL,
                              transform = NULL,
                              flush = NULL,
                              writeable_strategy = NULL,
                              readable_strategy = NULL) {
            transform_setup_default_stream(
                self,
                private,
                start,
                transform,
                flush,
                writeable_strategy,
                readable_strategy
            )
            invisible(self)
        },

        #' @description
        #' 1
        #' @return NULL
        close = function() transform_close(self, private),

        #' @description
        #' 1
        #' @return NULL
        abort = function() transform_abort(self, private),

        #' @description
        #' 1
        #' @param chunk 1
        #' @return NULL
        write = function(chunk) private$ws$write(chunk),

        #' @description
        #' 1
        #' @param destination 1
        #' @return NULL
        pipe = function(destination) private$rs$pipe(destination),

        #' @description
        #' 1
        #' @return NULL
        tee = function() private$rs$tee(),

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
        #' @field desired_size
        #' 1
        desired_size = function() private$rs$desired_size,

        #' @field current_state
        #' 1
        current_state = function() transform_get_state(self, private),

        #' @field readable
        #' 1
        readable = function() private$rs,

        #' @field writeable
        #' 1
        writeable = function() private$ws,

        #' @field controller
        #' 1
        controller = function() transform_get_controller(self, private)
    ),
    private = list(
        # streams
        rs = NULL,
        ws = NULL,

        # state
        start_result = NULL,
        started = NULL,
        stored_error = NULL,
        backpressure = NULL,

        # algorithms
        start_algorithm = NULL,
        transform_algorithm = NULL,
        flush_algorithm = NULL,
        finalize = function() {
            if (rlang::is_interactive()) {
                self$abort()
            } else {
                self$close()
            }
        }
    ),
    cloneable = FALSE
)

# ~~~ state ~~~~~~~~~~~~~

transform_get_state <- function(self, private) {
    rs_state <- private$rs$current_state
    ws_state <- private$ws$current_state

    if (all(c(rs_state, ws_state) == "closed")) {
        "closed"
    } else if (any(c(rs_state, ws_state) == "errored")) {
        "errored"
    } else {
        rs_state
    }
}

# ~~~ operations ~~~~~~~~


transform_setup_default_stream <- function(
    self,
    private,
    start,
    transform,
    flush,
    writeable_strategy,
    readable_strategy) {
    private$start_algorithm <- start %||% no_op_function
    private$transform_algorithm <- transform %||% identity_transform
    private$flush_algorithm <- flush %||% no_op_function

    private$backpressure <- FALSE

    start_promise <- promise_once(self, "start")

    prototype_promise_then(
        transform_start(self, private),
        function(v) {
            private$start_result <- v
            self$emit("start")
        },
        function(e) transform_error(self, private, e)
    )

    transform_setup_readable(self, private, start_promise, readable_strategy)
    transform_setup_writeable(self, private, start_promise, writeable_strategy)
    transform_connect_streams(self, private)
    transform_initialise_listeners(self, private)
}

transform_setup_readable <- function(self, private, start_promise, readable_strategy) {
    private$rs <- ReadableStream$new(
        start = function(...) transform_start_algorithm(private, start_promise),
        pull = function(...) transform_pull_algorithm(self, private),
        abort = function(...) transform_abort(self, private),
        queue_strategy = readable_strategy
    )
}

transform_setup_writeable <- function(self, private, start_promise, writeable_strategy) {
    private$ws <- WriteableStream$new(
        start = function(...) transform_start_algorithm(private, start_promise),
        write = function(chunk, ...) transform_write_algorithm(self, private, chunk),
        flush = function(...) private$flush_algorithm(self$controller),
        abort = function(...) transform_abort(self, private),
        queue_strategy = writeable_strategy
    )
}

transform_connect_streams <- function(self, private) {
    self$writeable$lock_stream(self$readable)
    self$readable$set_upstream(self$writeable)

}

transform_initialise_listeners <- function(self, private) {
    self$on(internal_events$stream_error, function(e) {
        private$stored_error <- e
        self$emit("error", e)
        lapply(c(self$readable, self$writeable), function(stream) {
            if (!stream_is_errored_or_closed(stream)) {
                stream$abort()
            }
        })
    })

    self$on("pipe", function(x) {
        self$writeable$emit("pipe", x)
    })

    # only add data listener to readable when the transform receives a data listener
    self$prepend_listener("new_listener", function(event_name, ...) {
        if (event_name == "data" && length(self$raw_listeners("data")) == 0L) {
            self$readable$on("data", function(data) {
                self$emit("data", data)
            })
        }
    })

    self$writeable$on("any", function(event_name, ...) {
        switch(
            event_name,
            "close" = {
                private$start_algorithm <- NULL
                private$transform_algorithm <- NULL
                self$readable$close()
            }
        )
    })

    self$readable$on("any", function(event_name, ...) {
        switch(event_name,
            "close" = {
                self$emit("close")
                private$flush_algorithm <- NULL
                self$remove_all_listeners()
            },
            "tee" = self$emit("tee")
        )
    })

    lapply(c(self$readable, self$writeable), function(stream) {
        stream$on("error", function(e) {
            self$emit(internal_events$stream_error, e)
        })
    })
}

transform_get_controller <- function(self, private) {
    list(
        emit = self$emit,
        desired_size = self$desired_size,
        start_value = private$start_result,
        enqueue = function(chunk) transform_enqueue(self, private, chunk),
        close = self$close,
        abort = self$abort,
        error = function(e) transform_error(self, private, e)
    )
}

transform_enqueue <- function(self, private, chunk) {
    tryCatch(
        expr = {
            private$rs$controller$enqueue(chunk)
        }, error = function(e) transform_error(self, private, e)
    )

    transform_set_backpressure(self, private)
}

transform_start_algorithm <- function(private, start_promise) {
    start_promise$then(onFulfilled = function(v) {
        private$start_result
    })
}

transform_pull_algorithm <- function(self, private) {
    transform_set_backpressure(self, private)
}

transform_should_transform <- function(self, private) {
    self$readable$desired_size > 0L
}

transform_write_algorithm <- function(self, private, chunk) {
    if (private$backpressure) {
        promise_once(self, "drain")$then(
            onFulfilled = function() {
                    prototype_promise_then(
                        private$transform_algorithm(
                            chunk,
                            self$controller
                        ),
                        no_op_function,
                        function(e) transform_error(self, private, e)
                    )
            }
        )
    } else {
            prototype_promise_then(
                private$transform_algorithm(
                    chunk,
                    self$controller
                ),
                no_op_function,
                function(e) transform_error(self, private, e)
            )
    }
}

transform_set_backpressure <- function(self, private) {
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

transform_start <- function(self, private) {
    private$started <- TRUE
    private$start_algorithm(self$controller)
}

transform_error <- function(self, private, error) {
    if (!is.null(self$current_state) && self$current_state != "error") {
        self$readable$controller$error(error)
        private$ws$abort()
    }
}

transform_close <- function(self, private) {
    if (!stream_is_errored_or_closed(self)) {
        self$writeable$close()
        self$readable$close()
    }
}

transform_abort <- function(self, private) {
    if (!stream_is_errored_or_closed(self)) {
        self$writeable$abort()
        self$readable$abort()
    }
}

identity_transform <- function(chunk, controller) {
    controller$enqueue(chunk)
}