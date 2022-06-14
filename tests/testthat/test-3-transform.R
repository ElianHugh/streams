source("expectations.R")

test_that("transform stream changes state appropriately", {
    transformer <- TransformStream$new()
    transformer$write(1L)
    expect_stream_state("started", transformer)

    wait_forcer <- WriteableStream$new(queue_strategy = QueueStrategy$new(-1, length))
    transformer %|>% wait_forcer
    expect_stream_state("waiting", transformer)

    transformer$abort()
    expect_stream_state("closed", transformer)

    transformer <- TransformStream$new()$on("error", function(...) "")
    transformer$controller$error("An error")
    expect_stream_state("errored", transformer)
})

test_that("transform stream outputs correctly", {
    x <- NULL
    reader <- as_reader(1L:10L)
    transformer <- TransformStream$new() |>
        on("data", function(dat) {
            x <<- append(x, dat)
        })
    reader %|>% transformer

    expect_object_length(x, 10L, transformer$readable)
})


testthat::test_that("transform write works", {
    tfm <- TransformStream$new(
        transform = function(chunk, controller) {
            controller$enqueue(as.character(chunk))
        }
    )
    tfm$write(5L)
    wait_for_async()
    expect_queue_size(1L, tfm$readable)
})
