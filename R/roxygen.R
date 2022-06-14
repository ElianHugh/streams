#' @title Readable Controller
#' @name Readable Controller
#'
#' @description
#' The controller object passed to the ReadableStream's functions is a list with references
#' to the underlying stream object.
#'
#' @details
#' Members:
#' * desired_size
#' * start_value
#'
#' Methods:
#' * emit
#' * enqueue
#' * close
#' * error
#'
#' @eval doc_member_section(
#' "desired_size",
#' "Reference to streams::`ReadableStream$desired_size`"
#' )
#'
#' @eval doc_member_section(
#' "start_value",
#' "The return value of the stream's start function",
#' "# the start value can be used to store a connection for
#' # reference during the pull method
#' r <- ReadableStream$new(
#'     start = function(controller) {
#'         x <- file(tempfile())
#'          if (!isOpen(x)) {
#'                open(x)
#'           }
#'        x
#'     },
#'     pull = function(controller) {
#'         out <- readLines(c$start_value, n = 1L)
#'        if (length(out) > 0L) {
#'            c$enqueue(out)
#'        } else {
#'            c$close()
#'        }
#'     }
#' )"
#' )
#'
#' @eval doc_method_section(
#' "enqueue",
#' "Pushes a chunk of data into the stream's internal queue",
#' list(chunk = "Data that will be pushed into the stream's queue")
#' )
#'
#' @eval doc_method_section(
#' "close",
#' "Order the stream to close when possible. \n\n
#' Specifically, the stream will enter a \"close_requested\" state.
#' Whenever the internal buffer reaches a size of `0`, the stream will stop processing data and will close.",
#' list(chunk = "Data that will be pushed into the stream's queue")
#' )
#'
#' @eval doc_method_section(
#' "error",
#' "Orders the stream to be put into an errored state.",
#' list(e = "Reason given for throwing an error")
#' )
#'
#' @seealso streams::ReadableStream
#' @rdname readable_controller
NULL

doc_member_section <- function(name, description, ...) {
    hr <- "\n\n\\if{html}{\\out{<hr>}}\n"
    section <- "@section Member \\code{%s}:\n"
    desc <- "%s\n"
    if (!missing(...)) {
        e <- as.list(...)
        etemp <- "\\subsection{Examples}{
            \\if{html}{\\out{<div class=\"r example copy\">}}
            \\preformatted{
                %s
            }}"
        examples <- sprintf(etemp, paste0(e, collapse = "\n\n"))
    } else {
        examples <- ""
    }

    paste0(
        sprintf(section, name),
        sprintf(desc, description),
        examples,
        hr,
        collapse = "\n"
    )
}

doc_method_section <- function(name, description, args, ...) {
    hr <- "\n\n\\if{html}{\\out{<hr>}}\n"
    section <- "@section Method \\code{%s()}:\n"
    desc <- "%s\n"
    arguments <- "\\subsection{Arguments}{\n\\describe{\n%s\n}"
    items <- lapply(seq_along(args), function(index) {
        name <- names(args[index])
        val <- args[[index]]
        i <- "\\item{\\code{%s}}{%s}"
        sprintf(i, name, val)
    })

    if (!missing(...)) {
        e <- as.list(...)
        etemp <- "\\subsection{Examples}{
            \\if{html}{\\out{<div class=\"r example copy\">}}
            \\preformatted{
                %s
            }}"
        examples <- sprintf(etemp, paste0(e, collapse = "\n\n"))
    } else {
        examples <- ""
    }

    paste0(
        sprintf(section, name),
        sprintf(desc, description),
        sprintf(
            arguments,
            paste0(items, collapse = "\n")
        ),
        examples,
        hr,
        "}",
        collapse = "\n"
    )
}

docs_start_fn <- function() {
    '@param start a function that is called once the stream enters the "started" state.
    Must be of signature: function(controller)'
}

docs_pull_fn <- function() {
    "@param pull a function that is called whenever
    the stream wants more data in its buffer. Must be of signature: function(controller)"
}

docs_write_fn <- function() {
    "@param write a function that is called whenever the stream attempts to write to the underlying source.
    Must be of signature: function(chunk, controller)"
}

docs_transform_fn <- function() {
    "@param transform a function that is called whenever the stream attempts to write to the readable end
    of the stream. Must be of signature: function(chunk, controller)"
}

docs_flush_fn <- function() {
    "@param flush a function that is called prior to the stream ending.
    Must be of signature: function(controller)"
}

docs_abort_fn <- function() {
    "@param abort a function that is called to immediately abort
    the stream, dropping all unconsumed chunks in the process. Must be of signature: function(controller)"
}

docs_queue_obj <- function() {
    "@param queue_strategy a QueueStrategy object, describing how chunks will be buffered by the stream"
}

docs_controller_obj <- function(stream_type) {
    fns <- switch(stream_type,
        "readable" = "start, pull, flush, and abort",
        "writeable" = "start, write, flush, and abort",
        "transform" = "start, transform, flush, and abort"
    )
    out <- sprintf(
        "The controller object passed to the %s functions is a list with references
        to the underlying stream object. Specifically, it has the following members:

        * emit
        * desired_size
        * start_value
        * enqueue
        * close
        * error",
        fns
    )
    c(
        "@section Stream Controller:",
        out
    )
}

docs_readable_examples <- function(type) {
    cont <- "@examples
   # A simple file stream
    %s(
        start = function(controller) {
            open(tempfile())
        },
        pull = function(controller) {
            res <- readLines(controller$start_value, n = 1L)
            if (length(res) > 0L) {
                controller$enqueue(res)
            } else {
                controller$close()
            }
        },
        flush = function(controller) {
            close(controller$start_value)
        }
    )

    # A stream with a generator function
    %s(
        start = function(controller) {
            gen <- function(x) {
                n <- length(x)
                i <- 0L
                function() {
                    if (i == n) {
                        return(NULL)
                    }
                    i <<- i + 1L
                    x[[i]]
                }
            }
            gen(1:100)
        },
        pull = function(controller) {
            value <- controller$start_value()
            if (!is.null(value)) {
                controller$enqueue(value)
            } else {
                controller$close()
            }
        }
    )
 "
    sprintf(cont, type, type)
}


docs_readable_pipe <- function() {
    '@description
     Pipe the stream to a WriteableStream.
     Pulled data from the ReadableStream is written to he WriteableStream,
     respecting backpressure signals from the riteableStream.

     When piped, the ReadableStream is in a locked tate, and cannot
     be manually controlled.

     Specifics:
     - Upon calling pipe(), the ReadableStream emits a pipe" event.
     - Data events will cause the ReadableStream to rite to the WriteableStream
     - The ReadableStream listens to the riteableStream\'s drain and backpressure events,
     pausing and resuming flow when appropriate
     - When a "close" event is emitted from the eadableStream,
     the WriteableStream is sent a close request
     - When an "error" event is emitted from the eadableStream,
     it is propogated to the WriteableStream.
    '
}
