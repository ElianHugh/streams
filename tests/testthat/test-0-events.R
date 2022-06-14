test_that("events can be listened to", {
    output <- 0L
    ee <- EventEmitter$new()
    ee$on("event", function() {
        output <<- output + 1L
    })
    expect_identical(ee$listener_count("event"), 1L)
    ee$emit("event")
    expect_identical(output, 1L)
    ee$emit("event")
    expect_identical(output, 2L)
})

test_that("any event can be listened to", {
    output <- 0L
    ee <- EventEmitter$new()
    ee$on("any", function(event_name, ...) {
        output <<- output + 1L
    })
    ee$emit("event")
    ee$emit("another")
    expect_identical(output, 2L)
})

test_that("event listeners can be removed", {
    output <- 0L
    increment <- function() {
        output <<- output + 1L
    }
    ee <- EventEmitter$new()
    ee$on("event", increment)
    expect_identical(ee$listener_count("event"), 1L)
    ee$emit("event")
    expect_identical(output, 1L)
    ee$off("event", increment)
    ee$emit("event")
    expect_identical(output, 1L)
    expect_identical(ee$listener_count("event"), 0L)

    ee$on("event", increment)
    ee$on("event", increment)
    ee$on("another", increment)
    ee$on("another", increment)
    ee$on("again", increment)
    expect_identical(ee$listener_count("event"), 2L)
    ee$remove_all_listeners("event")
    expect_identical(ee$listener_count("event"), 0L)
    expect_identical(ee$listener_count("another"), 2L)
    expect_identical(ee$listener_count("again"), 1L)
    ee$remove_all_listeners()
    expect_identical(ee$event_names(), c())
})


test_that("events can be listened to once", {
    output <- 0L
    ee <- EventEmitter$new()
    ee$once("event", function() {
        output <<- output + 1L
    })
    expect_identical(length(ee$raw_listeners("event")), 1L)
    ee$emit("event")
    expect_identical(length(ee$raw_listeners("event")), 0L)
    expect_identical(output, 1L)
    ee$emit("event")
    expect_identical(output, 1L)
})

test_that("event listeners can be prepended", {
    output <- 0L
    prep_called <- FALSE

    ee <- EventEmitter$new()
    ee$on("event", function() {
        output <<- 1L
    })
    ee$prepend_listener("event", function() {
        output <<- 5L
        prep_called <<- TRUE
    })

    expect_identical(ee$listener_count("event"), 2L)
    ee$emit("event")
    expect_identical(output, 1L)
    expect_true(prep_called)
})

test_that("emitter 'error' works", {
    # unhandled
    ee <- EventEmitter$new()
    output <- capture_error(ee$emit("error", "an error"))
    expect_error(ee$emit("error", "an error"))
    expect_s3_class(output, "emitters-unhandled_error_event-error")

    # bad eval
    output <- NULL
    expected_message <- "an error occured"
    ee <- EventEmitter$new()
    ee$on("event", function() {}) #nolint
    ee$on("error", function(e) {
        output <<- e
    })
    ee$emit("event", stop("an error occured"))
    expect_identical(unlist(output)$message, expected_message)
})

test_that("emitter warns on listener leak", {
    ee <- EventEmitter$new()
    max_l <- ee$get_max_listeners()
    for (i in seq(max_l)) {
        ee$on("event", no_op_function)
    }
    expect_warning(ee$on("event", no_op_function))

    ee <- EventEmitter$new()
    max_l2 <- ee$set_max_listeners(11L)
    for (i in seq(max_l)) {
        ee$on("event", no_op_function)
    }
    expect_warning(ee$on("event", no_op_function), regexp = NA)
    expect_warning(ee$on("event", no_op_function))
})

test_that("emitter lists event names accurately, and does not expose internals", {
    ee <- EventEmitter$new()
    ee$on("event", no_op_function)
    ee$on("another", no_op_function)
    ee$on(internal_events$stream_error, no_op_function)
    ee$on(internal_events$pipe_error, no_op_function)
    ee$on(internal_events$tee_error, no_op_function)

    expect_identical(ee$event_names(), c("event", "another"))
})
