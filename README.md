# Rosencrantz

Rosencrantz is a DSL to write web servers, inspired by [Spray](http://spray.io/)
and its successor [Akka HTTP](http://doc.akka.io/docs/akka/2.4.2/scala/http/introduction.html).

It sits on top of [asynchttpserver](http://nim-lang.org/docs/asynchttpserver.html)
and provides a composable way to write HTTP handlers.

<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [Rosencrantz](#rosencrantz)
	- [Introduction](#introduction)
		- [Composing handlers](#composing-handlers)
		- [Starting a server](#starting-a-server)
	- [An example](#an-example)
	- [Basic handlers](#basic-handlers)
		- [Path handling](#path-handling)
		- [HTTP methods](#http-methods)
		- [Querystring extraction](#querystring-extraction)
		- [Working with headers](#working-with-headers)
		- [Failure containment](#failure-containment)
	- [JSON support](#json-support)
	- [Form handling support](#form-handling-support)
	- [Static file support](#static-file-support)

<!-- /TOC -->

## Introduction

The core abstraction in Rosencrantz is the `Handler`, which is just an alias
for a `proc(req: ref Request, ctx: Context): Future[Context]`. Here `Request`
is the HTTP request from `asynchttpserver`, while `Context` is a place where
we accumulate information such as:

* what part of the path has been matched so far;
* what headers to emit with the response;
* whether the request has matched a route so far.

A handler usually does one or more of the following:

* filter the request, by returning `ctx.reject()` if some condition is not
  satisfied;
* accumulate some headers;
* actually respond to the request, by calling the `complete` function or one
  derived from it.

Rosencrantz provides many of those handlers, which are described below.

### Composing handlers

The nice thing about handlers is that they are composable. There are two ways
to compose two headers `h1` and `h2`:

* `h1 -> h2` (read `h1` **and** `h2`) returns a handler that passes the request
  through `h1` to update the context; then, if `h1` does not reject the request,
  it passes it, together with the new context, to `h2`. Think filtering first
  by HTTP method, then by path.
* `h1 ~ h2` (read `h1` **or** `h2`) returns a handler that passes the request
  through `h1`; if it rejects the request, it tries again with `h2`. Think
  matching on two alternative paths.

The combination `h1 -> h2` can also be written `h1[h2]`, which makes it nicer
when composing many handlers one inside each other.

### Starting a server

Once you have a handler, you can serve it using a server from `asynchttpserver`,
like this:

```nim
let server = newAsyncHttpServer()

waitFor server.serve(Port(8080), handler)
```

## An example

The following uses some of the predefined handlers and composes them together.
We write a small piece of a fictionary API to save and retrieve messages, and
we assume we have functions such as `getMessageById` that perform the actual
business logic. This should give a feel of how the DSL looks like:

```nim
let handler = get[
  path("/api/status")[
    ok(getStatus())
  ] ~
  pathChunk("/api/message")[
    accept("application/json")[
      intSegment(proc(id: int): auto =
        let message = getMessageById(id)
        ok(message)
      )
    ]
  ]
] ~ post [
  path("/api/new-message")[
    jsonBody(proc(msg: Message): auto =
      let
        id = generateId()
        saved = saveMessage(id, msg)
      if saved: ok(id)
      else: complete(Http500, "save failed")
    )
  ]
]
```

## Basic handlers

In order to work with Rosencrantz, you can `import rosencrantz`. If you prefer
a more fine-grained control, there are packages `rosen/core` (which contains the
definitions common to all handlers), `rosen/handlers` (for the handlers we are
about to show), and then more specialized handlers under `rosen/jsonsupport`,
`rosen/formsupport` and so on.

The simplest handlers are:

* `complete(code, body, headers)` that actually responds to the request. Here
  `code` is an instance of `HttpCode` from `asynchttpserver`, `body` is a
	`string` and `headers` are an instance of `StringTableRef`.
* `ok(body)`, which is a specialization of `complete` for a response of `200 Ok`
  with a content type of `text/plain`.
* `notFound(body)`, which is a specialization of `complete` for a response of
	`404 Not Found` with a content type of `text/plain`.
* `body(p)` extracts the body of the request. Here `p` is a
  `proc(s: string): Handler` which takes the extracted body as input and
	returns a handler.

For instance, a simple handler that echoes back the body of the request would
look like

```nim
body(proc(s: string): auto =
	ok(s)
)
```

### Path handling

There are a few handlers to filter by path and extract path parameters:

* `path(s)` filters the requests where the path is equal to `s`.
* `pathChunk(s)` does the same but only for a prefix of the path. This means
  that one can nest more path handlers after it, unlike `path`, that matches
	and consumes the whole path.
* `segment(p)`, that extracts a segment of path among two `/` signs. Here `p`
  is a `proc(s: string): Handler` that takes the matched segment and return a
	handler. This fails if the position is not just before a `/` sign.
* `intSegment(p)`, works the same as `segment`, but extracts and parses an
  integer number. It fails if the segment does not represent an integer. Here
	`p` is a `proc(s: int): Handler`.

For instance, to match and extract parameters out of a route like
`repeat/$msg/$n`, one would nest the above to get

```nim
pathChunk("/repeat")[
	segment(proc(msg: string): auto =
		intSegment(proc(n: int): auto =
			someHandler
		)
	)
]
```

### HTTP methods

To filter by HTTP method, one can use

* `verb(m)`, where `m` is a member of the `HttpMethod` enum defined in
  `rosen/core`. There are corresponding specializations
* `get`, `post`, `put`, `delete`, `head`, `patch`, `options`, `trace` and
  `connect`

### Querystring extraction

TBD

### Working with headers

There are various handlers to read HTTP headers, filter requests by their
values, or accumulate HTTP headers for the response.

* `headers(h1, h2, ...)` adds headers for the response. Here each argument is
  a tuple of two strings, which are a key/value pair.
* `contentType(s)` is a specialization to emit the `Content-Type` header, so
  is is equivalent to `headers(("Content-Type", s))`.
* `readAllHeaders(p)` extract the headers as a string table. Here `p` is a
  `proc(hs: StringTableRef): Handler`.
* `readHeaders(s1, p)` extracts the value of the header with key `s1` and
  passes it to `p`, which is of type `proc(h1: string): Handler`. It rejects
	the request if the header `s1` is not defined. There are overloads
	`readHeaders(s1, s2, p)` and `readHeaders(s1, s2, s3, p)`, where `p` is a
	function of two arguments (resp. three arguments). To extract more than
	three headers, one can use `readAllHeaders` or nest `readHeaders` calls.
* `tryReadHeaders(s1, p)` works the same as `readHeaders`, but it does not
  reject the request if header `s` is missing; instead, `p` receives an empty
	string as default. Again, there are overloads for two and three arguments.
* `checkHeaders(h1, h2, ...)` filters the request for the header value. Here
  `h1` and the other are pairs of strings, representing a key and a value. If
	the request does not have the corresponding headers with these values, it
	will be rejected.
* `accept(mimetype)` is equivalent to `checkHeaders(("Accept", mimetype))`.

For example, if you can return a result both as JSON or XML, according to the
request, you can do

```nim
accept("application/json")[
	contentType("application/json")[
		ok(someJsonValue)
	]
] ~ accept("text/xml")[
	contentType("text/xml")[
		ok(someXmlValue)
	]
]
```

### Failure containment

When a requests falls through all routes without matching, Rosencrantz will
return a standard response of `404 Not Found`. Similarly, whenever an
exception arises, Rosencrantz will respond with `500 Server Error`.

Sometimes, it can be useful to have more control over failure cases. For
instance, you are able only to generate responses with type `application/json`:
if the `Accept` header does not match it, you may want to return a status code
of `406 Not Accepted`.

One way to do this is to put the 406 response as an alternative, like this:

```nim
accept("application/json")[
	someResponse
] ~ complete(Http406, "JSON endpoint")
```

However, it can be more clear to use an equivalent combinators that wraps
an existing handler and it returns a given failure message in case the inner
handler fails to match. For this, there is

* `failWith(code, s)`, to be used like this:

```nim
failWith(Http406, "JSON endpoint")(
	accept("application/json")[
		someResponse
	]
)
```

## JSON support

Rosencrantz has support to parse and respond with JSON, under the
`rosen/jsonsupport` module. It defines two typeclasses:

* a type `T` is `JsonReadable` if there is function `readFromJson(json, T): T`
  where `json` is of type `JsonNode`;
* a type `T` is `JsonWritable` if there is a function
  `renderToJson(t: T): JsonNode`.

The module `rosen/core` contains the following handlers:

* `ok(j)`, where `j` is of type `JsonNode`, that will respond with a content
  type of `application/json`.
* `ok(t)`, where `t` has a type `T` that is `JsonWritable`, that will respond
  with the JSON representation of `t` and a content type of `application/json`.
* `jsonBody(p)`, where `p` is a `proc(j: JsonNode): Handler`, that extracts the
  body as a `JsonNode` and passes it to `p`, failing if the body is not valid
	JSON.
* `jsonBody(p)`, where `p` is a `proc(t: T): Handler`, where `T` is a type that
  is `JsonReadable`; it extracts the body as a `T` and passes it to `p`, failing
	if the body is not valid JSON or cannot be converted to `T`.

## Form handling support

Rosencrantz has support to read the body of a form, either of type
`application/x-www-form-urlencoded` or multipart (to be done).

The module `rosen/formsupport` defines the following handlers:

* `formBody(p)` where `p` is a `proc(s: StringTableRef): Handler`. It will
  parse the body as an URL-encoded form and pass the corresponding string
	table to `p`, rejecting the request if the body is not parseable.

## Static file support

TBD