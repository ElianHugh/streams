#' Coerce an object to a readable stream
#'
#' @description
#' `as_reader` turns an existing object into a readable stream.
#' Coercion can be used when you want to create a readable stream from a known
#' data source. In general, this is the easiest way to create a readable stream.
#'
#' As an S3 generic, `as_reader` holds methods for:
#'
#' * `base::data.frame`: creates a generator function that pushes
#' one row of a data.frame at a time into the stream
#' * connection: pulls chunks from a connection line by line, closing when a 0-length
#' string is returned
#' * `promises::promise`: uses the eventual output (`onFulfilled` value) of the promise as a chunk source.
#' If a rejection occurs, the stream will be errored.
#' * default: create an iterator through `coro::as_iterator`,
#' which is then used to supply chunks to the stream
#'
#' @param x object to coerce
#' @param queue_strategy optionally specify the queue strategy of the stream
#'
#' @examples
#' # create a readable stream from a numeric vector
#' reader <- as_reader(1:10)
#' on(reader, "data", print)
#'
#' @return `streams::ReadableStream`
#' @export
as_reader <- function(x, queue_strategy) {
    UseMethod("as_reader")
}

#' @export
as_reader.default <- function(x, queue_strategy = NULL) {
    start <- function(controller) {
        coro::as_iterator(x)
    }
    pull <- function(controller) {
        out <- controller$start_value()
        if (coro::is_exhausted(out)) {
            controller$close()
        } else {
            controller$enqueue(out)
        }
    }
    ReadableStream$new(
        start = start,
        pull = pull,
        queue_strategy = queue_strategy %||% object_length_strategy
    )
}

#' @export
as_reader.data.frame <- function(x, queue_strategy = NULL) {
    start <- function(controller) {
        n <- nrow(x)
        i <- 0L
        function() {
            if (i == n) {
                return(coro::exhausted())
            }
            i <<- i + 1L
            x[i, ]
        }
    }
    pull <- function(controller) {
        out <- controller$start_value()
        if (coro::is_exhausted(out)) {
            controller$close()
        } else {
            controller$enqueue(out)
        }
    }
    ReadableStream$new(
        start = start,
        pull = pull,
        queue_strategy = queue_strategy %||% object_length_strategy
    )
}


#' @export
as_reader.sockconn <- function(x, queue_strategy = NULL) {
    ReadableStream$new(
        start = function(controller) {
            x
        },
        pull = function(controller) {
            if (isOpen(controller$start_value)) {
                out <- readLines(controller$start_value, n = 1L)
                if (length(out) > 0L) {
                    controller$enqueue(out)
                }
            } else {
                controller$close()
            }
        },
        flush = function(controller) {
            close(controller$start_value)
        },
        queue_strategy = queue_strategy %||% object_length_strategy
    )
}

#' @export
as_reader.connection <- function(x, queue_strategy = NULL) {
    ReadableStream$new(
        start = function(controller) {
            if (!isOpen(x)) {
                open(x)
            }
            x
        },
        pull = function(controller) {
            out <- readLines(controller$start_value, n = 1L)
            if (length(out) > 0L) {
                controller$enqueue(out)
            } else {
                controller$close()
            }
        },
        flush = function(controller) {
            close(controller$start_value)
        },
        queue_strategy = queue_strategy %||% object_length_strategy
    )
}

#' @export
as_reader.promise <- function(x, queue_strategy = NULL) {
    start <- function(controller) {
        x$then(
            onFulfilled = function(v) {
                controller$enqueue(v)
                controller$close()
            },
            onRejected = function(e) {
                controller$error(e)
            }
        )
        I(x)
    }
    ReadableStream$new(
        start = start,
        queue_strategy = queue_strategy %||% object_length_strategy
    )
}

#' @export
as_reader.process <- function(x, queue_strategy = NULL) {
    stdout_pipe <- x$has_output_connection()
    stderr_pipe <- x$has_error_connection()

    ReadableStream$new(
        start = function(controller) {
            x
        },
        pull = function(controller) {
            if (!controller$start_value$is_alive()) {
                controller$close()
            }
            if (stdout_pipe) {
                out <- controller$start_value$read_output_lines()
                if (length(out) > 0L) {
                    controller$enqueue(out)
                }
            }
            if (stderr_pipe) {
                out <- controller$start_value$read_error_lines()
                if (length(out) > 0L) {
                    controller$enqueue(out)
                }
            }
        },
        flush = function(controller) {
            controller$start_value$kill()
        },
        queue_strategy = queue_strategy %||% object_length_strategy
    )
}

#' Coerce an object to a writeable stream
#'
#' @description
#' `as_writer` turns an existing object into a writeable stream.
#' Coercion can be used when you want to write to a known
#' data sink In general, this is the easiest way to create a writeable stream.
#'
#' As an S3 generic, `as_writer` holds methods for:
#'
#' * character: creates a stream that appends all chunks to a variable specified by the character input
#' * connection: write to a file, coercing chunks to a character vector where required
#' * default: throws an error
#'
#' @param x object to coerce
#' @param queue_strategy optionally specify the queue strategy of the stream
#'
#'
#' @examples
#' # create a writeable stream from a file path
#' writer <- as_writer(file(tempfile()))
#'
#' @return `streams::WriteableStream`
#' @export
#' @export
as_writer <- function(x, queue_strategy) {
    UseMethod("as_writer")
}

#' @export
as_writer.default <- function(x, queue_strategy = NULL) {
    rlang::abort(
        c(
            "Cannot coerce object to write stream.",
            sprintf("No S3 method exists for object of class '%s'.", class(x)[[1L]])
        )
    )
}

#' @export
as_writer.sockconn <- function(x, queue_strategy = NULL) {
    WriteableStream$new(
        start = function(controller) {
            x
        },
        write = function(chunk, controller) {
            if (!is.character(chunk)) {
                chunk <- as.character(chunk)
            }
            writeLines(
                text = chunk,
                con = controller$start_value
            )
        },
        flush = function(controller) {
            close(controller$start_value)
        },
        queue_strategy = queue_strategy %||% object_length_strategy
    )
}

#' @export
as_writer.connection <- function(x, queue_strategy = NULL) {
    WriteableStream$new(
        start = function(controller) {
            summ <- summary(x)$description
            if ("file" %in% class(x) && !file.exists(summ)) {
                file.create(summ)
            }
            if (!isOpen(x)) {
                open(x)
            }
            x
        },
        write = function(chunk, controller) {
            if (!is.character(chunk)) {
                chunk <- as.character(chunk)
            }
            writeLines(
                text = chunk,
                con = controller$start_value
            )
        },
        flush = function(controller) {
            close(controller$start_value)
        },
        queue_strategy = queue_strategy %||% object_length_strategy
    )
}

#' @export
as_writer.character <- function(x, queue_strategy = NULL) {
    env <- rlang::caller_env()

    WriteableStream$new(
        start = function(controller) {
            assign(
                x,
                NULL,
                env
            )
            rlang::as_name("sym")
        },
        write = function(chunk, controller) {
            assign(
                x,
                append(
                    get(x, env),
                    chunk
                ),
                env
            )
        },
        queue_strategy = queue_strategy %||% object_length_strategy
    )
}

#' @export
as_writer.process <- function(x, queue_strategy = NULL) {
    if (x$has_input_connection()) {
        WriteableStream$new(
            start = function(controller) {
                x
            },
            write = function(chunk, controller) {
                if (!is.character(chunk)) {
                    chunk <- as.character(chunk)
                }
                chunk <- paste0(chunk, "\n")
                controller$start_value$write_input(chunk)
            },
            flush = function(controller) {
                controller$start_value$kill()
            },
            queue_strategy = queue_strategy %||% object_length_strategy
        )
    } else {
        rlang::abort("process does not have an input connection.")
    }
}