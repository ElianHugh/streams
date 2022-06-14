stream_env <- new.env()

.onLoad <- function(...) {
    stream_env$stream_loop <- later::create_loop()
}
