
# ~~ wrappers ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

close_wrapper <- function(con, ...) {
    con$close()
}

format_desired_size <- function(x) {
    if (rlang::is_installed("crayon")) {
        if (is.null(x)) {
            crayon::red("NULL")
        } else if (x > 0L) {
            x
        } else {
            crayon::style(x, "grey60")
        }
    } else {
        x
    }
}

format_stream <- function(self, private) {
    out <- unlist(lapply(names(self), function(x) {
        tryCatch(
            expr = {
                sprintf("%s : %s", x, class(self[[x]]))
            },
            error = function(e) {
                x
            }
        )
    }))
    cat(
        out,
        sep = "\n"
    )
}

stream_print <- function(self, private) {
    summ <- summary(self)
    nms <- names(summ)
    values <- unlist(unname(summ))
    values[values == "errored"] <- crayon::red("errored")

    if (rlang::is_installed("crayon")) {
        wrapped_out <- crayon::col_align(nms, width = max(crayon::col_nchar(nms)), align = "left", type = "width")
        cat(
            crayon::style(
                "# A data stream:",
                "grey60"
            ),
            sprintf(
                "    %s : %s",
                wrapped_out,
                values
            ),
            sep = "\n"
        )
    } else {
        cat(
            "# A data stream:",
            sprintf(
                "    %s : %s",
                nms,
                values
            ),
            sep = "\n"
        )
    }
}



# ~~ user facing ~~~~~~~~~~~~~~




#' These are designed to be reminiscent of
#' the summary produced by connections.
#'
#' Basically, try to make streams feel like
#' the connection objects that people are familiar with0

#' @description
#' 1
#' @param object todo
#' @param ... todo
#' @export
summary.ReadableStream <- function(object, ...) {
    obj_class <- class(object)[[1L]]
    source_class <- class(object$controller$start_value)[[1L]]
    if (source_class == "AsIs") {
        source_class <- class(object$controller$start_value)[[2L]]
    }
    list(
        source = source_class,
        class = obj_class,
        state = object$current_state,
        can_read = TRUE,
        can_write = FALSE,
        desired_size = object$desired_size %||% 0L
    )
}

#' @description
#' 1
#' @param object todo
#' @param ... todo
#' @export
summary.WriteableStream <- function(object, ...) {
    obj_class <- class(object)[[1L]]
    sink_class <- class(object$controller$start_value)[[1L]]
    list(
        sink = sink_class,
        class = obj_class,
        state = object$current_state,
        can_read = FALSE,
        can_write = TRUE,
        desired_size = object$desired_size %||% 0L
    )
}

#' @description
#' 1
#' @param object todo
#' @param ... todo
#' @export
summary.TransformStream <- function(object, ...) {
    obj_class <- class(object)[[1L]]
    list(
        class = obj_class,
        state = object$current_state,
        can_read = TRUE,
        can_write = TRUE,
        transform_desired_size = object$writeable$desired_size %||% 0L,
        readable_desired_size = object$readable$desired_size %||% 0L
    )
}

#' @export
close.ReadableStream <- close_wrapper

#' @export
close.WriteableStream <- close_wrapper

#' @export
close.ReadableStream <- close_wrapper
