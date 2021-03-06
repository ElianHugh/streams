% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ReadableStream.R
\name{ReadableStream}
\alias{ReadableStream}
\title{ReadableStream}
\description{
An abstraction for reading streaming data.

When retrieved from an underlying source,
data will be buffered in an internal queue.

Data can be consumed by either attaching a "data"
listener, piping, or teeing the stream.
}
\details{
Events:
\itemize{
\item start
\item error
\item data
\item pipe
\item tee
\item close
}
}
\seealso{
readable_controller

Other streams: 
\code{\link{TransformStream}},
\code{\link{WriteableStream}}
}
\concept{streams}
\section{Super class}{
\code{\link[streams:EventEmitter]{streams::EventEmitter}} -> \code{ReadableStream}
}
\section{Active bindings}{
\if{html}{\out{<div class="r6-active-bindings">}}
\describe{
\item{\code{current_state}}{1}

\item{\code{is_locked}}{1}

\item{\code{is_ready}}{A boolean value of whether the stream is ready to accept chunks.
This does not, however, mean that the stream is \emph{able} to accept chunks
(e.g. if it has a full buffer).}

\item{\code{controller}}{A list that is passed to start, pull, and abort methods. Contains references to the following:
\itemize{
\item emit
\item desired_size
\item start_value
\item enqueue
\item close
}}

\item{\code{desired_size}}{1}
}
\if{html}{\out{</div>}}
}
\section{Methods}{
\subsection{Public methods}{
\itemize{
\item \href{#method-ReadableStream-new}{\code{ReadableStream$new()}}
\item \href{#method-ReadableStream-pipe}{\code{ReadableStream$pipe()}}
\item \href{#method-ReadableStream-tee}{\code{ReadableStream$tee()}}
\item \href{#method-ReadableStream-abort}{\code{ReadableStream$abort()}}
\item \href{#method-ReadableStream-close}{\code{ReadableStream$close()}}
\item \href{#method-ReadableStream-lock_stream}{\code{ReadableStream$lock_stream()}}
\item \href{#method-ReadableStream-set_upstream}{\code{ReadableStream$set_upstream()}}
\item \href{#method-ReadableStream-print}{\code{ReadableStream$print()}}
\item \href{#method-ReadableStream-format}{\code{ReadableStream$format()}}
\item \href{#method-ReadableStream-clone}{\code{ReadableStream$clone()}}
}
}
\if{html}{\out{
<details><summary>Inherited methods</summary>
<ul>
<li><span class="pkg-link" data-pkg="streams" data-topic="EventEmitter" data-id="emit"><a href='../../streams/html/EventEmitter.html#method-EventEmitter-emit'><code>streams::EventEmitter$emit()</code></a></li>
<li><span class="pkg-link" data-pkg="streams" data-topic="EventEmitter" data-id="event_names"><a href='../../streams/html/EventEmitter.html#method-EventEmitter-event_names'><code>streams::EventEmitter$event_names()</code></a></li>
<li><span class="pkg-link" data-pkg="streams" data-topic="EventEmitter" data-id="get_max_listeners"><a href='../../streams/html/EventEmitter.html#method-EventEmitter-get_max_listeners'><code>streams::EventEmitter$get_max_listeners()</code></a></li>
<li><span class="pkg-link" data-pkg="streams" data-topic="EventEmitter" data-id="listener_count"><a href='../../streams/html/EventEmitter.html#method-EventEmitter-listener_count'><code>streams::EventEmitter$listener_count()</code></a></li>
<li><span class="pkg-link" data-pkg="streams" data-topic="EventEmitter" data-id="off"><a href='../../streams/html/EventEmitter.html#method-EventEmitter-off'><code>streams::EventEmitter$off()</code></a></li>
<li><span class="pkg-link" data-pkg="streams" data-topic="EventEmitter" data-id="on"><a href='../../streams/html/EventEmitter.html#method-EventEmitter-on'><code>streams::EventEmitter$on()</code></a></li>
<li><span class="pkg-link" data-pkg="streams" data-topic="EventEmitter" data-id="once"><a href='../../streams/html/EventEmitter.html#method-EventEmitter-once'><code>streams::EventEmitter$once()</code></a></li>
<li><span class="pkg-link" data-pkg="streams" data-topic="EventEmitter" data-id="prepend_listener"><a href='../../streams/html/EventEmitter.html#method-EventEmitter-prepend_listener'><code>streams::EventEmitter$prepend_listener()</code></a></li>
<li><span class="pkg-link" data-pkg="streams" data-topic="EventEmitter" data-id="prepend_once_listener"><a href='../../streams/html/EventEmitter.html#method-EventEmitter-prepend_once_listener'><code>streams::EventEmitter$prepend_once_listener()</code></a></li>
<li><span class="pkg-link" data-pkg="streams" data-topic="EventEmitter" data-id="raw_listeners"><a href='../../streams/html/EventEmitter.html#method-EventEmitter-raw_listeners'><code>streams::EventEmitter$raw_listeners()</code></a></li>
<li><span class="pkg-link" data-pkg="streams" data-topic="EventEmitter" data-id="remove_all_listeners"><a href='../../streams/html/EventEmitter.html#method-EventEmitter-remove_all_listeners'><code>streams::EventEmitter$remove_all_listeners()</code></a></li>
<li><span class="pkg-link" data-pkg="streams" data-topic="EventEmitter" data-id="set_max_listeners"><a href='../../streams/html/EventEmitter.html#method-EventEmitter-set_max_listeners'><code>streams::EventEmitter$set_max_listeners()</code></a></li>
</ul>
</details>
}}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReadableStream-new"></a>}}
\if{latex}{\out{\hypertarget{method-ReadableStream-new}{}}}
\subsection{Method \code{new()}}{
Create a new ReadableStream
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReadableStream$new(
  start = NULL,
  pull = NULL,
  flush = NULL,
  abort = NULL,
  queue_strategy = NULL
)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{start}}{a function that is called once the stream enters the "started" state.
Must be of signature: function(controller)}

\item{\code{pull}}{a function that is called whenever
the stream wants more data in its buffer. Must be of signature: function(controller)}

\item{\code{flush}}{a function that is called prior to the stream ending.
Must be of signature: function(controller)}

\item{\code{abort}}{a function that is called to immediately abort
the stream, dropping all unconsumed chunks in the process. Must be of signature: function(controller)}

\item{\code{queue_strategy}}{a QueueStrategy object, describing how chunks will be buffered by the stream}
}
\if{html}{\out{</div>}}
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReadableStream-pipe"></a>}}
\if{latex}{\out{\hypertarget{method-ReadableStream-pipe}{}}}
\subsection{Method \code{pipe()}}{
Pipe the ReadableStream to a WriteableStream.
Pulled data from the ReadableStream is written to the WriteableStream,
respecting backpressure signals from the WriteableStream.

When piped, the ReadableStream is in a locked state, and cannot
be manually controlled.

Specifics:
\itemize{
\item Upon calling pipe(), the ReadableStream emits a "pipe" event.
\item Data events will cause the ReadableStream to write to the WriteableStream
\item The ReadableStream listens to the WriteableStream's drain and backpressure events,
pausing and resuming flow when appropriate
\item When a "close" event is emitted from the ReadableStream,
the WriteableStream is sent a close request
\item When an "error" event is emitted from the ReadableStream,
it is propogated to the WriteableStream.
}
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReadableStream$pipe(destination)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{destination}}{ReadableStream}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
destination
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReadableStream-tee"></a>}}
\if{latex}{\out{\hypertarget{method-ReadableStream-tee}{}}}
\subsection{Method \code{tee()}}{
Tee the ReadableStream, creating two ReadableStreams in the process.
Data from this ReadableStream will flow into the two destination streams,
and will respect backpressure signals from both destination streams.

Specifics:
\itemize{
\item Upon calling tee(), the ReadableStream will emit a "tee" event.
\item The resulting teed streams act as push streams, wherein the data from the
teeing stream is pushed when appropriate
\item Data is only pushed when both streams are able to accept new chunks,
otherwise the chunks will be buffered inside the teeing stream
\item The queue strategy of the teeing stream is respected
\item The teed streams utilise the default queue strategy, accepting one chunk at a time
}
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReadableStream$tee()}\if{html}{\out{</div>}}
}

\subsection{Returns}{
list of teed streams
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReadableStream-abort"></a>}}
\if{latex}{\out{\hypertarget{method-ReadableStream-abort}{}}}
\subsection{Method \code{abort()}}{
1
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReadableStream$abort(reason = NULL)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{reason}}{data}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
NULL
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReadableStream-close"></a>}}
\if{latex}{\out{\hypertarget{method-ReadableStream-close}{}}}
\subsection{Method \code{close()}}{
1
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReadableStream$close()}\if{html}{\out{</div>}}
}

\subsection{Returns}{
NULL
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReadableStream-lock_stream"></a>}}
\if{latex}{\out{\hypertarget{method-ReadableStream-lock_stream}{}}}
\subsection{Method \code{lock_stream()}}{
1
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReadableStream$lock_stream(destination)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{destination}}{1}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
NULL
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReadableStream-set_upstream"></a>}}
\if{latex}{\out{\hypertarget{method-ReadableStream-set_upstream}{}}}
\subsection{Method \code{set_upstream()}}{
1
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReadableStream$set_upstream(destination)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{destination}}{1}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
NULL
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReadableStream-print"></a>}}
\if{latex}{\out{\hypertarget{method-ReadableStream-print}{}}}
\subsection{Method \code{print()}}{
1
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReadableStream$print()}\if{html}{\out{</div>}}
}

\subsection{Returns}{
NULL
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReadableStream-format"></a>}}
\if{latex}{\out{\hypertarget{method-ReadableStream-format}{}}}
\subsection{Method \code{format()}}{
1
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReadableStream$format(...)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{...}}{1}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
NULL
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-ReadableStream-clone"></a>}}
\if{latex}{\out{\hypertarget{method-ReadableStream-clone}{}}}
\subsection{Method \code{clone()}}{
The objects of this class are cloneable with this method.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{ReadableStream$clone(deep = FALSE)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{deep}}{Whether to make a deep clone.}
}
\if{html}{\out{</div>}}
}
}
}
