
#' Stream pipe
#'
#' @description
#' Pipe the left-hand side stream into the right-hand side stream.
#' Returns the right-hand side for further use.
#'
#' @param lhs tbd
#' @param rhs tbd
#'
#' @family pipes
#' @rdname streampipe
#' @name streampipe
#' @export
`%|>%` <- function(lhs, rhs) {
    invisible(lhs$pipe(rhs))
}

#'  Tee pipe
#'
#' @description
#' Tees a readablestream, piping the left branch
#' into the right-hand side stream, and returning
#' the right branch for further use.
#'
#' @examples
#' # create a stream that prints the data sent to it
#' # and also increments each chunk by one
#' stream <- as_reader(1:100) %T>%
#'     walk_stream(function(data) print(data)) %|>%
#'     map_stream(function(data) data + 1)
#'
#' @param lhs stream to be teed
#' @param rhs stream to be piped to
#' @family pipes
#' @rdname teepipe
#' @export
`%T>%` <- function(lhs, rhs) {
    tstream <- lhs$tee()
    tstream[[1L]]$pipe(rhs)
    invisible(tstream[[2L]])
}

#' On event
#' @description
#' 1
#' @param emitter 1
#' @param event 1
#' @param fn 1
#' @family events
#' @export
on <- function(emitter, event, fn) {
    emitter$on(event, fn)
}

#' Once event
#' @description
#' 1
#' @param emitter 1
#' @param event 1
#' @param fn 1
#' @family events
#' @export
once <- function(emitter, event, fn) {
    emitter$once(event, fn)
}
