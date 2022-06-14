# simple FIFO queue
Queue <- R6::R6Class(
    "Queue",
    public = list(
        initialize = function() {
            private$queue <- collections::queue()
        },
        add = function(x) private$queue$push(x),

        remove = function(n = 1L, missing = NULL) queue_remove_objects(self, private, n, missing),

        peek = function() private$queue$peek(),

        reset = function() private$queue$clear(),

        as_list = function() private$queue$as_list()
    ),
    private = list(
        queue = NULL
    ),
    active = list(
        size = function() private$queue$size()
    ),
    class = FALSE,
    cloneable = FALSE
)


queue_remove_objects <- function(self, private, n, missing) {
queue_len <- private$queue$size()
            if (n == -1L) {
                res <- lapply(
                    seq_len(queue_len),
                    queue_pop_object_or_null,
                    private
                )
                unlist(res, recursive = FALSE, use.names = FALSE)
            } else if (queue_len > 0L) {
                res <- lapply(
                    seq_len(n),
                    queue_pop_object_or_null,
                    private
                )
                unlist(res, recursive = FALSE, use.names = FALSE)
            } else {
                missing
            }
}

queue_pop_object_or_null <- function(drop = NULL, private) {
    tryCatch(
            expr = {
                private$queue$pop()
            },
            error = function(e) {
                NULL
            }
    )
}

#' Queue Strategy
#' @description
#' 1
#' @family queue_strategies
#' @export
QueueStrategy <- R6::R6Class(
    public = list(
        #' @description
        #' Create a new queue strategy
        #' @param highwater_mark number denoting when a stream should stop asking for more data
        #' @param size_algorithm function that is used to measure the size of the stream queue
        initialize = function(highwater_mark, size_algorithm) {
            pretty_stopifnot(
                sprintf("highwater_mark is of class '%s'", class(highwater_mark)),
                "highwater_mark must be a numeric vector",
                is.numeric(highwater_mark)
            )
            pretty_stopifnot(
                sprintf("size_algorithm is of class '%s'", class(size_algorithm)),
                "size_algorithm must be a function",
                is.function(size_algorithm)
            )

            private$highwater <- highwater_mark
            private$size_algorithm <- size_algorithm
        },
        #' @description
        #' A function that is applied to a chunk in order to determine its size.
        #' @param chunk a data chunk
        #' @return numeric vector
        size = function(chunk) {
            private$size_algorithm(chunk)
        }
    ),
    active = list(
        #' @field highwater_mark
        #' A number representing the queue size at which a stream will stop attempting to receive more chunks
        highwater_mark = function() private$highwater
    ),
    private = list(
        highwater = NULL,
        size_algorithm = NULL
    ),
    classname = NULL,
    class = FALSE,
    cloneable = FALSE
)

#' No backpressure strategy
#' @description
#' A queue strategy where there is no highwater mark specified, meaning that the queue size is potentially infinite.
#' Specifically, the function `length` is used, with a highwater mark of `Inf`.
#' @family queue_strategies
#' @export
no_backpressure_strategy <- QueueStrategy$new(Inf, length)

#' Object length strategy
#' @description
#' A queue strategy where the queue size is determined by the length of the object.
#' Specifically, the function `length` is used, with a highwater mark of `1L`.
#' @family queue_strategies
#' @export
object_length_strategy <- QueueStrategy$new(1L, length)

#' Byte size queue strategy
#' @description
#' A queue strategy where the queue siz is determined by the byte size of the object.
#' Specifically, the function `object.size` is used, with a highwater mark of 16 * 1024.
#' @family queue_strategies
#' @export
byte_size_strategy <- QueueStrategy$new(16L * 1024L, object.size)
