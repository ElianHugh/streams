#' Async once-event
#' @param emitter an EventEmitter object
#' @param event character vector
#' @family async
#' @export
promise_once <- function(emitter, event) {
    promises::promise(function(resolve, reject) {
        emitter$once(event, function(...) {
            if (missing(...)) {
                resolve(NULL)
            }
            resolve(...)
        })
        emitter$once("error", function(...) {
            if (missing(...)) {
                reject(NULL)
            }
            reject(...)
        })
    })
}


#' Event Emitter
#'
#' @export
EventEmitter <- R6Class(
    "EventEmitter",
    public = list(
        #' @param event_name TODOC
        #' @param fn TODOC
        on = function(event_name, fn) {
            pretty_stopifnot(
                "argument `fn` supplied to emitter must be a function",
                sprintf("fn is of class '%s'", class(fn)),
                is.function(fn)
            )
            lapply(event_name, emitter_add_listener, self, private, fn)
            invisible(self)
        },

        #' @param event_name TODOC
        #' @param fn TODOC
        prepend_listener = function(event_name, fn) {
            pretty_stopifnot(
                "argument `fn` supplied to emitter must be a function",
                sprintf("fn is of class '%s'", class(fn)),
                is.function(fn)
            )
            lapply(event_name, emitter_add_listener, self, private, fn, TRUE)
            invisible(self)
        },

        #' @param event_name TODOC
        #' @param fn TODOC
        once = function(event_name, fn) {
            pretty_stopifnot(
                "argument `fn` supplied to emitter must be a function",
                sprintf("fn is of class '%s'", class(fn)),
                is.function(fn)
            )
            lapply(event_name, emitter_once_listener, self, private, fn)
            invisible(self)
        },

        #' @param event_name TODOC
        #' @param fn TODOC
        prepend_once_listener = function(event_name, fn) {
            pretty_stopifnot(
                "argument `fn` supplied to emitter must be a function",
                sprintf("fn is of class '%s'", class(fn)),
                is.function(fn)
            )
            lapply(event_name, emitter_once_listener, self, private, fn, TRUE)
            invisible(self)
        },

        #' @param event_name TODOC
        #' @param fn TODOC
        off = function(event_name, fn) {
            pretty_stopifnot(
                "argument `fn` supplied to emitter must be a function",
                sprintf("fn is of class '%s'", class(fn)),
                is.function(fn)
            )
            self$emit("remove_listener", event_name, fn)
            if (!is.null(private$listeners[[event_name]])) {
                matches <- unlist(lapply(private$listeners[[event_name]], function(x) identical(x, fn)))
                private$listeners[[event_name]][
                    matches
                ] <- NULL
            }
            invisible(self)
        },

        #' @param event_name TODOC
        remove_all_listeners = function(event_name) {
            if (missing(event_name)) {
                private$listeners <- list()
            } else {
                private$listeners[[event_name]] <- NULL
            }
            invisible(self)
        },

        #' @param event_name TODOC
        #' @param ... arguments to pass to functions registered to a given event
        emit = function(event_name, ...) emitter_emit_event(self, private, event_name, ...),

        #' @param event_name TODOC
        listener_count = function(event_name) length(private$listeners[[event_name]]),

        #' @param event_name TODOC
        raw_listeners = function(event_name) private$listeners[[event_name]],

        #' @description
        #' TODOC
        event_names = function() {
            ev_names <- names(private$listeners)
            return(ev_names[ev_names %nin% internal_events])
        },

        #' @param n TODOC
        set_max_listeners = function(n) {
            private$max_listeners <- n
            invisible(self)
        },

        #' @description
        #' TODOC
        get_max_listeners = function() private$max_listeners
    ),
    private = list(
        listeners = list(),
        max_listeners = 10L,
        with_error_handler = function(code) emitter_with_error_handler(self, private, code)
    ),
    cloneable = FALSE
)

emitter_add_listener <- function(event_name, self, private, fn, prepend_listener = FALSE) {
    self$emit("new_listener", event_name, fn)
    emitter_check_listener_length(self, private, event_name)
    if (prepend_listener) {
        private$listeners[[event_name]] <- prepend(private$listeners[[event_name]], fn)
    } else {
        private$listeners[[event_name]] <- append(private$listeners[[event_name]], fn)
    }
}

emitter_once_listener <- function(event_name, self, private, fn, prepend_listener = FALSE) {
    self$emit("new_listener", event_name, fn)
    emitter_check_listener_length(self, private, event_name)
    wrapper <- emitter_once_wrapper(self, fn, event_name, wrapper)

    if (prepend_listener) {
        private$listeners[[event_name]] <- prepend(private$listeners[[event_name]], wrapper)
    } else {
        private$listeners[[event_name]] <- append(private$listeners[[event_name]], wrapper)
    }
}

emitter_emit_event <- function(self, private, event_name, ...) {
    event_listeners <- private$listeners[[event_name]]

    if (
        event_name == "error" &&
        is_falsey(event_listeners)) {
        return(error_unhandled_error_event(...))
    }

    emitter_call_listeners(self, private, event_listeners, event_name, ...)
    emitter_call_any(self, private, event_name, ...)

    invisible(TRUE)
}

emitter_once_wrapper <- function(self, fn, event_name, this) {
    structure(
        function(...) {
            fn(...)
            self$off(event_name, this)
        },
        attributes = "once_wrapper"
    )
}

emitter_call_listeners <- function(self, private, listeners, event_name, ...) {
    if (length(listeners) > 0L) {
        fn <- function() callback(...)
        private$with_error_handler(
            code = {
                for (callback in listeners) {
                    fn()
                }
            }
        )
    }
}

emitter_call_any <- function(self, private, event_name, ...) {
    any_listeners <- private$listeners[["any"]]
    if (length(any_listeners) > 0L) {
        fn <- function() callback(event_name, ...)
        private$with_error_handler(
            code = {
                for (callback in any_listeners) {
                    if (!is_once_wrapper(callback)) {
                        fn()
                    }
                }
            }
        )
    }
}

is_once_wrapper <- function(x) {
    attr <- attributes(x)[["attributes"]]
    !is.null(attr) && attr == "once_wrapper"
}

emitter_check_listener_length <- function(self, private, event_name) {
    count <- self$listener_count(event_name)
    if (count >= self$get_max_listeners()) {
        rlang::warn(
            c(
                "!" = "Possible <EventEmitter> leak detected.",
                i = sprintf(
                    "There are more listeners than expected for event: '%s'",
                    event_name
                ),
                " " = sprintf("Expected maximum: %s", private$max_listeners),
                " " = sprintf("Current value: %s", self$listener_count(event_name))
            )
        )
    }
}

emitter_with_error_handler <- function(self, private, code) {
    tryCatch(
        expr = {
            force(code)
        },
        error = function(e) {
            store_errors()
            self$emit("error", e)
        }
    )
}
