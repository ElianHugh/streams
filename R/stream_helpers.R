
#' TODOC
#'
#' @description
#' TODOC
#'
#' @export
#' @family classes
is_transform_stream <- function(stream) {
    inherits(stream, "TransformStream")
}

#' TODOC
#'
#' @description
#' TODOC
#'
#' @export
#' @family classes
is_readable_stream <- function(stream) {
    inherits(stream, "ReadableStream")
}

#' TODOC
#'
#' @description
#' TODOC
#'
#' @export
#' @family classes
is_writeable_stream <- function(stream) {
    inherits(stream, "WriteableStream")
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

stream_is_errored_or_closed <- function(self) {
    self$current_state %in% c("errored", "closed")
}

stream_is_closing_or_closed <- function(self, private) {
    self$current_state == "closed" || private$close_requested
}

stream_get_desired_size <- function(private) {
    tryCatch(
        expr = {
            if (private$state != "started") {
                switch(private$state,
                    "errored"  = NULL,
                    "waiting"  = 0L,
                    "starting" = 0L,
                    "closed"   = 0L
                )
            } else {
                private$desired_size_algorithm()
            }
        },
        error = function(e) {
            NULL
        }
    )
}

# stream flow
#           downstream      downstream
# stream A ---> stream B -----> stream C |
#         <-----        <----------------/
#           upstream          upstream

stream_is_empty_forever <- function(self, private) {
    empty_queue <- private$queue$size == 0L
    no_flow <- !stream_upstream_is_flowing(private)
    empty_queue && no_flow
}

stream_update_backpressure <- function(self, private) {
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


stream_set_downstream <- function(self, private, destination) {
    private$downstream <- append(private$downstream, destination)
    private$locked <- TRUE
}

stream_set_upstream <- function(self, private, destination) {
    private$upstream <- append(private$upstream, destination)
}

stream_remove_upstream <- function(private, upstream) {
    private$upstream <- splice_element(private$upstream, upstream)
}

stream_remove_downstream <- function(private, downstream) {
    private$downstream <- splice_element(private$downstream, downstream)
}

stream_upstream_is_flowing <- function(private) {
    res <- as.logical(lapply(private$upstream, function(x) {
        !stream_is_errored_or_closed(x)
    }))
    any(res)
}

stream_downstream_is_flowing <- function(private) {
    res <- as.logical(lapply(private$downstream, function(x) {
        !stream_is_errored_or_closed(x)
    }))
    any(res)
}
