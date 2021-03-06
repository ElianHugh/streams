% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/queue.R
\docType{data}
\name{byte_size_strategy}
\alias{byte_size_strategy}
\title{Byte size queue strategy}
\format{
An object of class \code{environment} of length 4.
}
\usage{
byte_size_strategy
}
\description{
A queue strategy where the queue siz is determined by the byte size of the object.
Specifically, the function \code{object.size} is used, with a highwater mark of 16 * 1024.
}
\seealso{
Other queue_strategies: 
\code{\link{QueueStrategy}},
\code{\link{no_backpressure_strategy}},
\code{\link{object_length_strategy}}
}
\concept{queue_strategies}
\keyword{datasets}
