source("expectations.R")

test_that("map", {
    x <- NULL

    mapper <- as_reader(1L:10L) %|>%
        map_stream(as.character) |>
        on("data", function(dat) {
            x <<- append(x, dat)
        })

    expect_object_length(x, 10L, mapper)
    expect_true(is.character(x[[1L]]))
})

test_that("filter", {
    x <- NULL

    filterer <- as_reader(1L:10L) %|>%
        filter_stream(~ .x >= 5L) |>
        on("data", function(dat) {
            x <<- append(x, dat)
        })

    expect_object_length(x, 6L, filterer)
    expect_true(x[[1L]] == 5L)
})

test_that("reduce", {
    x <- NULL

    reducer <- as_reader(1L:10L) %|>%
        reduce_stream(sum) |>
        on("data", function(dat) {
            x <<- dat
        })

    expect_object_length(x, 1L, reducer)
    expect_equal(x, 55L)
})

test_that("collect", {
    x <- NULL

    collector <- as_reader(1L:10L) %|>%
        collect_stream() |>
        on("data", function(dat) {
            x <<- dat
        })

    expect_object_length(x, 10L, collector)
    expect_equal(x, as.list(1L:10L))
})

test_that("batch", {
    x <- NULL

    batcher <- as_reader(1L:10L) %|>%
        batch_stream(5) |>
        on("data", function(dat) {
            x <<- append(x, list(dat))
        })

    expect_object_length(x, 2L, batcher)
    expect_equal(x, list(list(1L, 2L, 3L, 4L, 5L), list(6L, 7L, 8L, 9L, 10L)))
})

test_that("limit", {
    x <- NULL
    reader <- as_reader(1L:10L)$on("error", print)
    limiter <- reader %|>%
        limit_stream(5L, length)$
            on("data", function(dat) {
            x <<- append(x, dat)
        })$on("error", print)
    expect_object_length(x, 4L, limiter)
})

test_that("flatten", {
    x <- NULL
    y <- list(
        list(1L, 2L, 3L),
        list(4L, 5L, 6L)
    )
    flattener <- as_reader(1L:6L) %|>%
        flatten_stream() |>
        on("data", function(dat) {
            x <<- append(x, dat)
        })

    expect_object_length(x, 6L, flattener)
    expect_identical(x, unlist(y))
})