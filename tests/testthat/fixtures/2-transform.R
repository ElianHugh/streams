library(streams)

transformer <- TransformStream$new(
    transform = function(chunk, controller) {
        controller$enqueue(5L)
    }
)

r <- as_reader(1L:5L) %|>%
    transformer |>
    on("data", print)
