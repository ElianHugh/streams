source("expectations.R")

test_that("readable stream changes state appropriately", {
  reader <- as_reader(1L:10L)
  expect_stream_state("started", reader)

  wait_forcer <- WriteableStream$new(queue_strategy = QueueStrategy$new(-1L, length))
  reader %|>% wait_forcer
  expect_stream_state("waiting", reader)

  reader$abort()
  expect_stream_state("closed", reader)

  reader <- as_reader(1L:10L)$on("error", function(...) "")
  reader$controller$error("An error")
  expect_stream_state("errored", reader)
})

test_that("readable stream outputs correctly", {
  x <- NULL
  reader <- as_reader(1L:10L) |>
    on("data", function(dat) {
      x <<- append(x, dat)
    })

  expect_object_length(x, 10L, reader)
})

test_that("readable stream buffers appropriately", {
  reader <- as_reader(1L:10L) # default queue strategy = len 1

  wait_for_async()
  expect_stream_state("started", reader)
  expect_queue_size(1L, reader)

  out <- reader$.__enclos_env__$private$queue$peek()
  reader |> once("data", function(x) {
    # remove 1 item from queue
  })
  wait_for_async()
  out2 <- reader$.__enclos_env__$private$queue$peek()
  expect_false(out == out2)
})

test_that("readable stream can be aborted at a set point", {
  x <- NULL
  reader <- as_reader(1L:10L) |>
    on("data", function(dat) {
      if (length(x) >= 5L) {
        reader$abort()
      } else {
        x <<- append(x, dat)
      }
    })

  expect_object_length(x, 5L, reader)
  expect_stream_state("closed", reader)
})

test_that("readable stream can be errored at a set point", {
  x <- NULL

  reader <- as_reader(1L:10L)$
    on("data", function(dat) {
    if (length(x) >= 5L) {
      reader$controller$error("x greater than 5")
    } else {
      x <<- append(x, dat)
    }
  })$on("error", function(e) {})

  expect_object_length(x, 5L, reader)
  expect_stream_state("errored", reader)
  expect_stream_error_text("x greater than 5", reader)
  testthat::expect_error(reader$controller$enqueue(5L))
})

test_that("readable tee works", {
  t1 <- NULL
  t2 <- NULL

  reader <- as_reader(1L:10L)
  tees <- reader$tee()

  tees[[1L]]$on("data", function(x) t1 <<- append(t1, x))

  while (is.null(t1)) {
    later::run_now()
  }

  expect_length(t1, 1L)
  expect_length(t2, 0L)

  tees[[2L]]$on("data", function(x) t2 <<- append(t2, x))

  expect_object_length(t1, 10L, reader)
  expect_object_length(t2, 10L, reader)
  expect_identical(t1, t2)
  expect_stream_state("closed", reader)
})