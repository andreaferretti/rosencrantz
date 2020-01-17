# 1. Rosencrantz

![shakespeare](https://raw.githubusercontent.com/andreaferretti/rosencrantz/master/shakespeare.jpg)

Rosencrantz is a DSL to write web servers, inspired by [Spray](http://spray.io/)
and its successor [Akka HTTP](http://doc.akka.io/docs/akka/2.4.2/scala/http/introduction.html).

It sits on top of [asynchttpserver](http://nim-lang.org/docs/asynchttpserver.html)
and provides a composable way to write HTTP handlers.

Version 0.4 of Rosencrantz is tested with Nim 1.0.0, but is compatible with
versions of Nim from 0.19.0 on.

Table of contents
-----------------

<!-- TOC depthfrom:1 depthto:6 withlinks:false updateonsave:false orderedlist:false -->

- Rosencrantz
  - Introduction
    - Composing handlers
    - Starting a server
  - Structure of the package
  - An example
  - Basic handlers
    - Path handling
    - HTTP methods
    - Failure containment
    - Logging
  - Working with headers
  - Writing custom handlers
  - JSON support
  - Form and querystring support
  - Static file support
  - CORS support
  - API stability

<!-- /TOC -->

## 1.1. Introduction

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

Rosencrantz provides many of those handlers, which are described below. For the
complete API, check [here](http://andreaferretti.github.io/rosencrantz/rosencrantz.html).

### 1.1.1. Composing handlers

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
when composing many handlers one inside each other. Also remember that,
according to Nim rules, `~` has higher precedence than `->` - use parentheses
if necessary to compose your handlers.

### 1.1.2. Starting a server

Once you have a handler, you can serve it using a server from `asynchttpserver`,
like this:

```nim
let server = newAsyncHttpServer()

waitFor server.serve(Port(8080), handler)
```

## 1.2. Structure of the package

Rosencrantz can be fully imported with just

```nim
import rosencrantz
```

The `rosencrantz` module just re-exports functionality from the submodules
`rosencrantz/core`, `rosencrantz/handlers`, `rosencrantz/jsonsupport` and so
on. These modules can be imported separately. The API is available
[here](http://andreaferretti.github.io/rosencrantz/rosencrantz.html).

## 1.3. An example

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
] ~ post[
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

For more (actually working) examples, check the `tests` directory. In particular,
[the server example](https://github.com/andreaferretti/rosencrantz/blob/master/tests/server.nim)
tests every handler defined in Rosencrantz, while
[the todo example](https://github.com/andreaferretti/rosencrantz/blob/master/tests/todo.nim)
implements a server compliant with the [TODO backend project](http://www.todobackend.com/)
specs.

## 1.4. Basic handlers

In order to work with Rosencrantz, you can `import rosencrantz`. If you prefer
a more fine-grained control, there are packages `rosencrantz/core` (which
contains the definitions common to all handlers), `rosencrantz/handlers` (for
the handlers we are about to show), and then more specialized handlers under
`rosencrantz/jsonsupport`, `rosencrantz/formsupport` and so on.

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

### 1.4.1. Path handling

There are a few handlers to filter by path and extract path parameters:

* `path(s)` filters the requests where the path is equal to `s`.
* `pathChunk(s)` does the same but only for a prefix of the path. This means
  that one can nest more path handlers after it, unlike `path`, that matches
  and consumes the whole path.
* `pathEnd(p)` extracts whatever is not matched yet of the path and passes it
  to `p`. Here `p` is a `proc(s: string): Handler` that takes the final part of
  the path and returns a handler.
* `pathEnd(s)` filters the requests where the remaining path is equal
   to `s`. Defaults to case sensitive matching, but you can use
   `pathEnd(s, caseSensitive=false)` to do a case insensitive match.
* `segment(p)`, that extracts a segment of path among two `/` signs. Here `p`
  is a `proc(s: string): Handler` that takes the matched segment and return a
  handler. This fails if the position is not just before a `/` sign.
* `segment(s)` filters the requests where the current path segment is equal
   to `s`. Defaults to case sensitive matching, but you can use
   `segment(s, caseSensitive=false)` to do a case insensitive match.
   This fails if the position is not just before a `/` sign.
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

### 1.4.2. HTTP methods

To filter by HTTP method, one can use

* `verb(m)`, where `m` is a member of the `HttpMethod` enum defined in
  the standard library `httpcore`. There are corresponding specializations
* `get`, `post`, `put`, `delete`, `head`, `patch`, `options`, `trace` and
  `connect`

### 1.4.3. Failure containment

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

Similarly, you may want to customize the behaviour of Rosencrantz when the
application crashes.

* `crashWith(code, s, logError)` can be used to wrap your handler:

```nim
crashWith(Http500, "Sorry :-(")(
  accept("application/json")[
    someResponse
  ]
)
```

### 1.4.4. Logging

Rosencrantz supports logging in two different moments: when a request arrives,
or when a response is produced (of course you can also manually log at any other
moment). In the first case, you will only have available the information about
the current request, while in the latter both the request and the response
will be available.

The two basic handlers for logging are:

* `logRequest(s)`, where `s` is a format string. The string is used inside
  the system `format` function, and it is passed the following arguments in
  order:
  - the HTTP method of the request
  - the path of the resource
  - the headers, as a table
  - the body of the request, if any.
* `logResponse(s)`, where `s` is a format string. The first four arguments
  are the same as in `logRequest`; then there are
  - the HTTP code of the response
  - the headers of the response, as a table
  - the body of the response, if any.

So for instance, in order to log the incoming method and path, as well as the
HTTP code of the response, you can use the following handler:

```nim
logResponse("$1 $2 - $5")
```

which will produce log strings such as

```
GET /api/users/181 - 200 OK
```

## 1.5. Working with headers

Under `rosencrantz/headersupport`, there are various handlers to read HTTP
headers, filter requests by their values, or accumulate HTTP headers for the
response.

* `headers(h1, h2, ...)` adds headers for the response. Here each argument is
  a tuple of two strings, which are a key/value pair.
* `contentType(s)` is a specialization to emit the `Content-Type` header, so
  is is equivalent to `headers(("Content-Type", s))`.
* `readAllHeaders(p)` extract the headers as a string table. Here `p` is a
  `proc(hs: HttpHeaders): Handler`.
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
* `addDate()` returns a handler that adds the `Date` header, formatted as
  a GMT date in the [HTTP date format](https://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html).

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

## 1.6. Writing custom handlers

Sometimes, the need arises to write handlers that perform a little more custom
logic than those shown above. For those cases, Rosencrantz provides a few
procedures and templates (under `rosencrantz/custom`) that help creating
your handlers.

* `getRequest(p)`, where `p` is a `proc(req: ref Request): Handler`. This
  allows you to access the whole `Request` object, and as such allows more
  flexibility.
* `scope` is a template that creates a local scope. It us useful when one needs
  to define a few variables to write a little logic inline before returning an
  actual handler.
* `scopeAsync` is like scope, but allows asyncronous logic (for instance waiting
  on futures) in it.
* `makeHandler` is a macro that removes some boilerplate in writing a custom
  handler. It accepts the body of a handler, and surrounds it with the proper
  function declaration, etc.

An example of usage of `scope` is the following:

```nim
path("/using-scope")[
  scope do:
    let x = "Hello, World!"
    echo "We are returning: ", x
    return ok(x)
]
```

An example of usage of `scopeAsync` is the following:

```nim
path("/using-scope")[
  scopeAsync do:
    let x = "Hello, World!"
    echo "We are returning: ", x
    await sleepAsync(100)
    return ok(x)
]
```

An example of usage of `makeHandler` is the following:

```nim
path("/custom-handler")[
  makeHandler do:
    let x = "Hello, World!"
    await req[].respond(Http200, x, {"Content-Type": "text/plain;charset=utf-8"}.newStringTable)
    return ctx
]
```

That is expanded into something like:

```nim
path("/custom-handler")[
  proc innerProc() =
    proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
      let x = "Hello, World!"
      await req[].respond(Http200, x, {"Content-Type": "text/plain;charset=utf-8"}.newStringTable)
      return ctx

    return h

  innerProc()
]
```

Notice that `makeHandler` is a little lower-level than other parts of
Rosencrantz, and requires you to know how to write a custom handler.

## 1.7. JSON support

Rosencrantz has support to parse and respond with JSON, under the
`rosencrantz/jsonsupport` module. It defines two typeclasses:

* a type `T` is `JsonReadable` if there is function `readFromJson(json, T): T`
  where `json` is of type `JsonNode`;
* a type `T` is `JsonWritable` if there is a function
  `renderToJson(t: T): JsonNode`.

The module `rosencrantz/core` contains the following handlers:

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

## 1.8. Form and querystring support

Rosencrantz has support to read the body of a form, either of type
`application/x-www-form-urlencoded` or multipart. It also supports
parsing the querystring as `application/x-www-form-urlencoded`.

The `rosencrantz/formsupport` module defines two typeclasses:

* a type `T` is `UrlDecodable` if there is function `parseFromUrl(s, T): T`
  where `s` is of type `StringTableRef`;
* a type `T` is `UrlMultiDecodable` if there is a function
  `parseFromUrl(s, T): T` where `s` is of type `TableRef[string, seq[string]]`.

The module `rosencrantz/formsupport` defines the following handlers:

* `formBody(p)` where `p` is a `proc(s: StringTableRef): Handler`. It will
  parse the body as an URL-encoded form and pass the corresponding string
  table to `p`, rejecting the request if the body is not parseable.
* `formBody(t)` where `t` has a type `T` that is `UrlDecodable`. It will
  parse the body as an URL-encoded form, convert it to `T`, and pass the
  resulting object to `p`. It will reject a request if the body is not parseable
  or if the conversion to `T` fails.
* `formBody(p)` where `p` is a
  `proc(s: TableRef[string, seq[string]]): Handler`. It will parse the body as
  an URL-encoded form, accumulating repeated parameters into sequences, and pass
  table to `p`, rejecting the request if the body is not parseable.
* `formBody(t)` where `t` has a type `T` that is `UrlMultiDecodable`. It will
  parse the body as an URL-encoded with repeated parameters form, convert it
  to `T`, and pass the resulting object to `p`. It will reject a request if the
  body is not parseable or if the conversion to `T` fails.

There are similar handlers to extract the querystring from a request:

* `queryString(p)`, where `p` is a `proc(s: string): Handler` allows to generate
  a handler from the raw querystring (not parsed into parameters yet)
* `queryString(p)`, where `p` is a `proc(s: StringTableRef): Handler` allows to
  generate a handler from the querystring parameters, parsed as a string table.
* `queryString(t)` where `t` has a type `T` that is `UrlDecodable`; works the
  same as `formBody`.
* `queryString(p)`, where `p` is a
  `proc(s: TableRef[string, seq[string]]): Handler` allows to generate a handler
  from the querystring with repeated parameters, parsed as a table.
* `queryString(t)` where `t` has a type `T` that is `UrlMultiDecodable`; works
  the same as `formBody`.

Finally, there is a handler to parse multipart forms. The results are
accumulated inside a `MultiPart` object, which is defined by

```nim
type
  MultiPartFile* = object
    filename*, contentType*, content*: string
  MultiPart* = object
    fields*: StringTableRef
    files*: TableRef[string, MultiPartFile]
```

The handler for multipart forms is:

* `multipart(p)`, where `p` is a `proc(m: MultiPart): Handler` is handed
  the result of parsing the form as multipart. In case of parsing error, an
  exception is raised - you can choose whether to let it propagate it and
  return a 500 error, or contain it using `failWith`.

## 1.9. Static file support

Rosencrantz has support to serve static files or directories. For now, it is
limited to small files, because it does not support streaming yet.

The module `rosencrantz/staticsupport` defines the following handlers:

* `file(path)`, where `path` is either absolute or relative to the current
  working directory. It will respond by serving the content of the file, if
  it exists and is a simple file, or reject the request if it does not exist
  or is a directory.
* `dir(path)`, where `path` is either absolute or relative to the current
  working directory. It will respond by taking the part of the URL
  requested that is not matched yet, concatenate it to `path`, and serve the
  corresponding file. Again, if the file does not exist or is a directory, the
  handler will reject the request.

To make things concrete, consider the following handler:

```nim
path("/main")[
  file("index.html")
] ~
pathChunk("/static")[
  dir("public")
]
```

This will server the file `index.html` when the request is for the path `/main`,
and it will serve the contents of the directory `public` under the URL `static`.
So, for instance, a request for `/static/css/boostrap.css` will return the
contents of the file `./public/css/boostrap.css`.

All static handlers use the [mimetypes module](http://nim-lang.org/docs/mimetypes.html)
to try to guess the correct content type depending on the file extension. This
should be usually enough; if you need more control, you can wrap a `file`
handler inside a `contentType` handler to override the content type.

**Note** Due to a bug in Nim 0.14.2, the static handlers will not work on this
version. They work just fine on Nim 0.14.0 or on devel.


## 1.10. CORS support

Rosencrantz has support for [Cross-Origin requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Access_control_CORS)
under the module `rosencrantz/corssupport`.

The following are essentially helper functions to produce headers related to
handling cross-origin HTTP requests, as well as reading common headers in
preflight requests. These handlers are available:

* `accessControlAllowOrigin(origin)` produces the header `Access-Control-Allow-Origin`
  with the provided `origin` value.
* `accessControlAllowAllOrigins` produces the header `Access-Control-Allow-Origin`
  with the value `*`, which amounts to accepting all origins.
* `accessControlExposeHeaders(headers)` produces the header `Access-Control-Expose-Headers`,
  which is used to control which headers are exposed to the client.
* `accessControlMaxAge(seconds)` produces the header `Access-Control-Max-Age`,
  which controls the time validity for the preflight request.
* `accessControlAllowCredentials(b)`, where `b` is a boolean value, produces
  the header `Access-Control-Allow-Credentials`, which is used to allow the
  client to pass cookies and headers related to HTTP authentication.
* `accessControlAllowMethods(methods)`, where `methods` is an openarray of
  `HttpMethod`, produces the header `Access-Control-Allow-Methods`, which is
  used in preflight requests to communicate which methods are allowed on the
  resource.
* `accessControlAllowHeaders(headers)` produces the header `Access-Control-Allow-Headers`,
  which is used in the preflight request to control which headers can be added
  by the client.
* `accessControlAllow(origin, methods, headers)` is used in preflight requests
  for the common combination of specifying the origin as well as methods and
  headers accepted.
* `readAccessControl(p)` is used to extract information in the preflight request
  from the CORS related headers at once.
  Here `p` is a `proc(origin: string, m: HttpMethod, headers: seq[string]`
  that will receive the origin of the request, the desired method and the
  additional headers to be provided, and will return a suitable response.

## 1.11. API stability

While the basic design is not going to change, the API is not completely
stable yet. It is possible that the `Context` will change to accomodate some
more information, or that it will be passed as a `ref` to handlers.

As long as you compose the handlers defined above, everything will continue to
work, but if you write your own handlers by hand, this is something to be
aware of.
