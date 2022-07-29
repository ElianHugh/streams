# ~~~~~~~~~~~~~ Core functionals ~~~~~~~~~~~~~ #

#' Map stream
#'
#' @description
#' Apply function `fn` to each chunk of data
#'
#' @param fn function applied to each chunk of stream, the result of which is enqueued to
#' the readable side
#' @param ... arguments passed to TransformStream
#'
#' @examples
#' mapper <- as_reader(1:10) %|>%
#'     map_stream(as.character) |>
#'     on("data", print)
#'
#' @family functionals
#' @export
map_stream <- function(fn, ...) {
    fn <- to_function(fn)
    TransformStream$new(
        transform = function(chunk, controller) {
            res <- fn(chunk)
            controller$enqueue(res)
        },
        flush = function(controller) {
            fn <<- NULL
        },
        ...
    )
}

#' Filter stream
#'
#' @description
#' Filter a stream based on a boolean function, only passing data that results in a
#' true condition
#'
#' @param fn function applied to each chunk of stream that returns a boolean value
#' @param ... arguments passed to TransformStream
#'
#' @examples
#' filterer <- as_reader(1:10) %|>%
#'     filter_stream(~ .x < 5L) |>
#'     on("data", print)
#'
#' @family functionals
#' @export
filter_stream <- function(fn, ...) {
    fn <- to_function(fn)
    TransformStream$new(
        transform = function(chunk, controller) {
            res <- isTRUE(fn(chunk))
            if (res) {
                controller$enqueue(chunk)
            }
        },
        flush = function(controller) {
            fn <<- NULL
        },
        ...
    )
}

#' Reduce stream
#'
#' @description
#' Reduce stream data into one chunk via the iterative application of function `fn` to an accumulator and
#' each chunk
#'
#' See also `base::Reduce`
#'
#' @param fn a function that is applied to the current accumulation and the current chunk
#' @param base_value the base value of the accumulation
#' @param ... arguments passed to TransformStream
#'
#' @examples
#' as_reader(1:100) %|>%
#'     reduce_stream(sum) |>
#'     on("data", print)
#' @family functionals
#' @export
reduce_stream <- function(fn, base_value = 0L, ...) {
    accumulation <- base_value
    fn <- to_function(fn)
    TransformStream$new(
        transform = function(chunk, controller) {
            accumulation <<- fn(accumulation, chunk)
        },
        flush = function(controller) {
            controller$enqueue(accumulation)
            accumulation <<- NULL
            fn <<- NULL
        },
        ...
    )
}

# ~~~~~~~~~~~~~ Misc functionals ~~~~~~~~~~~~~ #

#' Walk stream
#'
#' @description
#' Map stream, but for side-effects
#'
#' @param fn function applied to each chunk of the stream,
#' but does not enqueue the changed chunk
#' @param ... arguments passed to TransformStream
#' @examples
#' as_reader(1:10) %|>%
#'  walk_stream(print) |>
#'  on("data", print)
#'
#' @family functionals
#' @export
walk_stream <- function(fn, ...) {
    fn <- to_function(fn)
    TransformStream$new(
        transform = function(chunk, controller) {
            fn(chunk)
            controller$enqueue(chunk)
        },
        flush = function(controller) {
            fn <<- NULL
        },
        ...
    )
}

#' Collect stream
#'
#' @description
#' Form of reduce stream where all data is appended to a list before
#' being emitted.
#'
#' @param ... arguments passed to reduce_stream
#' @examples
#' as_reader(1:10) %|>%
#'     collect_stream() |>
#'     on("data", print)
#'
#' @family functionals
#' @export
collect_stream <- function(...) {
    reduce_stream(
        fn = append,
        base_value = list(),
        ...
    )
}

#' Batch stream
#'
#' @description
#' Chunks that flow through a stream will be grouped
#' into lists of length `size` before being enqueued
#'
#' @param size the maximum length of each batch
#' @param ... arguments passed to TransformStream
#' @examples
#' as_reader(1:100) %|>%
#' batch_stream(10) |>
#'    on("data", print)
#' @family functionals
#' @export
batch_stream <- function(size, ...) {
    current_batch <- list()
    TransformStream$new(
        transform = function(chunk, controller) {
            current_batch <<- append(current_batch, chunk)
            if (length(current_batch) >= size) {
                controller$enqueue(current_batch)
                current_batch <<- list()
            }
        },
        flush = function(controller) {
            if (length(current_batch) > 0L) {
                controller$enqueue(current_batch)
            }
            current_batch <<- NULL
        },
        ...
    )
}

#' Limit stream
#'
#' @description
#' Limit the number of chunks that can run through a stream, closing
#' once a maximum length is reached
#'
#' @param max_length the maximum number of chunks that can run through a stream
#' @param size_fn a function that is used to increment the size counter
#' @param ... arguments passed to TransformStream
#' @examples
#' limiter <- as_reader(1:10) %|>%
#'     limit_stream(5L, length) |>
#'     on("data", print)
#'
#' @family functionals
#' @export
limit_stream <- function(max_length = 0L, size_fn, ...) {
    total_size <- 0L
    size <- size_fn
    TransformStream$new(
        start = function(c) {
            size
        },
        transform = function(chunk, controller) {
            total_size <<- total_size + size(chunk)
            if (total_size >= max_length) {
                controller$abort()
            } else {
                controller$enqueue(chunk)
            }
        },
        flush = function(controller) {
            total_size <<- NULL
        },
        ...
    )
}

#' Flatten stream
#'
#' @description
#' Chunks that pass through the stream are flattened one-level and their
#' individual elements are enqueued
#' @param ... arguments passed to TransformStream
#' @family functionals
#' @export
flatten_stream <- function(...) {
    TransformStream$new(
        transform = function(chunk, controller) {
            lapply(chunk, function(x) {
                controller$enqueue(x)
            })
        },
        ...
    )
}


# group_stream <- function(x) {
#     groups <- list()
#     readers <- list()
#     TransformStream$new(
#         transform = function(chunk, controller) {
#             v <- chunk[[x]]
#             pos <- which(groups == v)
#             if (v %nin% groups) {
#                 groups <- append(
#                     groups,
#                     v
#                 )
#                 readers <- append(
#                     readers,
#                     ReadableStream$new()
#                 )
#                 pos <- which(groups == v)
#                 readers[[pos]]$controller$enqueue(chunk)
#                 controller$enqueue(readers[[pos]])
#             } else {
#                 readers[[pos]]$controller$enqueue(chunk)
#             }
#         }
#     )$on("close", \() print(groups))
# }


zip_stream <- function(...) {
    zenv <- new.env()
    zenv$close_counter <- 0L
    zenv$input <- as.list(...)
    zenv$current_chunk <- data.frame(matrix(ncol = 2L, nrow = 0L))
    colnames(zenv$current_chunk) <- c("chunk", "stream_id")
    makeActiveBinding("required_len", function() {
        length(zenv$input)
    }, zenv)
    zenv$create_chunk <- function() {
        indexes <- which(!duplicated(zenv$current_chunk$stream_id))
        if (length(indexes) >= zenv$required_len) {
            out <- zenv$current_chunk[indexes, ]
            zenv$current_chunk <- zenv$current_chunk[-indexes, ]
            out
        } else {
            FALSE
        }
    }
    zenv$maybe_close <- function(zipper) {
        zenv$close_counter <- zenv$close_counter + 1L
        if (zenv$close_counter >= zenv$required_len && zipper$current_state != "closed") {
            zipper$close()
        }
    }


    zipper <- TransformStream$new(
        start = function(controller) {
            lapply(seq_along(zenv$input), function(index) {
                current_stream <- zenv$input[[index]]
                current_stream$lock_stream(zipper)
                current_stream$on("data", function(chunk) {
                    zipper$write(list(chunk, index))
                })
                current_stream$on("close", function() {
                    zenv$input <- splice_element(zenv$input, current_stream)
                    zenv$maybe_close(zipper)
                })
            })
            zenv$input
        },
        transform = function(chunk, controller) {
            next_chunk <- zenv$create_chunk()
            if (!isFALSE(next_chunk)) {
                controller$enqueue(next_chunk$chunk)
            }
            zenv$current_chunk <- rbind(
                zenv$current_chunk,
                list(chunk = chunk[[1L]], stream_id = chunk[[2L]])
            )
        },
        flush = function(controller) {
            if (nrow(zenv$current_chunk) > 0L) {
                controller$enqueue(zenv$current_chunk$chunk)
                zenv$current_chunk <- NULL
            }
            zenv <<- NULL
        },
        writeable_strategy = no_backpressure_strategy,
        readable_strategy = no_backpressure_strategy
    )
}
