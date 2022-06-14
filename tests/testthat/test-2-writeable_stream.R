source("expectations.R")

test_that("readable stream changes state appropriately", {
    textCon <- textConnection(NULL, "w")
    writer <- as_writer(textCon)
    expect_stream_state("started", writer)

    writer$abort()
    expect_stream_state("closed", writer)

    reader <- as_reader(1L:10L)$on("error", function(...) "")
    reader$controller$error("An error")
    expect_stream_state("errored", reader)
})

test_that("writeable stream outputs correctly", {
    writer <- as_writer("x")
    writer$write("Hello world!")
    expect_identical(x, "Hello world!")
})
