
<!-- README.md is generated from README.Rmd. Please edit that file -->

# streams

<!-- badges: start -->

[![:name status
badge](https://elianhugh.r-universe.dev/badges/:name)](https://elianhugh.r-universe.dev)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
[![R-CMD-check](https://github.com/ElianHugh/streams/workflows/R-CMD-check/badge.svg)](https://github.com/ElianHugh/streams/actions)
[![Codecov test
coverage](https://codecov.io/gh/ElianHugh/streams/branch/main/graph/badge.svg)](https://app.codecov.io/gh/ElianHugh/streams?branch=main)
<!-- badges: end -->

Data streams are an abstraction for flowing data – data that is not held
in-memory, but is accessed lazily when needed by the consumer. In
essence, a data stream is a data-processing object that sacrifices speed
for memory optimisation.

Package Aims:

  - Simple but extensible data streaming system
  - Easy to understand data flow state machine
  - Data agnostic

## Installation

Upon release, you can install streams from [my r-universe
repo](https://elianhugh.r-universe.dev/ui):

``` r
install.packages("streams", repos = "https://elianhugh.r-universe.dev")
```

Alternatively, you can install the development version of streams from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("ElianHugh/streams")
```

## Examples

### Stream creation

The simplest form of stream creation comes from the `as_reader` and
`as_writer` methods, which coerce a given object to a stream. See below
for a *very* brief overview of the stream system.

#### Readable Stream

Let’s create a read stream:

``` r
stream <- as_reader(1:5)
stream
#> # A data stream:
#>     source : function
#>     class : ReadableStream
#>     state : started
#>     can_read : TRUE
#>     can_write : FALSE
#>     desired_size : 1
```

In this state, the stream will not output any data. We can attach a
listener to cause the stream to flow:

``` r
stream |>
  on("data", print)

#> 1
#> 2
#> 3
#> 4
#> 5
```

#### Writeable Stream

Similarly, we can create a write stream:

``` r
stream <- as_writer("x")
stream
#> # A data stream:
#>     sink : character
#>     class : WriteableStream
#>     state : started
#>     can_read : FALSE
#>     can_write : TRUE
#>     desired_size : 1
```

We can then write data to the stream, which will write to the variable
`x`:

``` r
stream$write("Hello world!")
```

``` r
print(x)
#> [1] "Hello world!"
```

#### Stream Piping

We can pull all these together with the `%|>%` (stream pipe) command.
Not to be confused with the base `|>` or magrittr `%>%` pipe, the stream
pipe command is used to chain streams together.

Let’s try chaining the previous streams together:

``` r
as_reader(1L:5L) %|>%
  as_writer("x")
```

``` r
print(x)
#> [1] 1 2 3 4 5
```

## Inspiration

This package could not have been developed without the existence of data
streams in many other programming languages. In particular, the NodeJS
and web stream standard were instrumental in the design of {streams}.

  - [NodeJS streams](https://nodejs.org/api/stream.html)
  - [WHATWG Web Stream standard](https://streams.spec.whatwg.org/)
  - [Functional
    streams](https://www.npmjs.com/package/functional-streams)
  - [Stromjs](https://github.com/lewisdiamond/stromjs)

## Code of Conduct

Please note that the streams project is released with a [Contributor
Code of
Conduct](https://elianhugh.github.io/streams/CODE_OF_CONDUCT.html). By
contributing to this project, you agree to abide by its terms.
