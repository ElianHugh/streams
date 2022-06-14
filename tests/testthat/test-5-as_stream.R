source("expectations.R")

reader_coro_summary <- list(
    source = "function",
    class = "ReadableStream",
    state = "started",
    can_read = TRUE,
    can_write = FALSE,
    desired_size = 1L
)

reader_filecon_summary <- list(
    source = "file",
    class = "ReadableStream",
    state = "started",
    can_read = TRUE,
    can_write = FALSE,
    desired_size = 1L
)

reader_promise_summary <- list(
    source = "promise",
    class = "ReadableStream",
    state = "started",
    can_read = TRUE,
    can_write = FALSE,
    desired_size = 1L
)

test_that("as_reader coerces accurately and correctly", {
    # vector stream
    input <- 1L:10L
    output <- NULL
    reader <- as_reader(input)
    reader$on("data", function(dat) {
        output <<- append(output, dat)
    })
    expect_identical(summary(reader), reader_coro_summary)
    expect_object_length(output, 10L, reader)
    cleanup_stream(reader)

    # file stream
    input <- tempfile()
    file.create(input)
    input <- file(input)
    writeLines("test", con = input)
    output <- NULL
    reader <- as_reader(input)
    reader$on("data", function(dat) {
        output <<- append(output, dat)
    })
    expect_identical(summary(reader), reader_filecon_summary)
    expect_object_length(output, 1L, reader)
    cleanup_stream(reader)

    # promise stream
    input <- promises::promise(function(resolve, reject) {
        later::later(~ resolve(1L), delay = 0L)
    })
    output <- NULL
    reader <- as_reader(input)
    reader$on("data", function(dat) {
        output <<- append(output, dat)
    })
    expect_identical(summary(reader), reader_promise_summary)
    expect_object_length(output, 1L, reader)
    cleanup_stream(reader)
})

writer_var_summary <- list(
    sink = "character",
    class = "WriteableStream",
    state = "started",
    can_read = FALSE,
    can_write = TRUE,
    desired_size = 1L
)

writer_filecon_summary <- list(
    sink = "file",
    class = "WriteableStream",
    state = "started",
    can_read = FALSE,
    can_write = TRUE,
    desired_size = 1L
)

test_that("as_writer coerces accurately and correctly", {
    # variable stream
    output <- NULL
    writer <- as_writer("output")
    writer$write("test")
    expect_identical(summary(writer), writer_var_summary)
    expect_object_length(output, 1L, writer)
    cleanup_stream(writer)

    # filecon stream
    input <- tempfile()
    file.create(input)
    input <- file(input, open = "r+b")
    writer <- as_writer(input)
    writer$write("test")
    expect_identical(summary(writer), writer_filecon_summary)
    expect_identical(readLines(input), "test")
    cleanup_stream(writer)
})