library(streams)

as_reader(1L:10L) |>
    on("data", print)