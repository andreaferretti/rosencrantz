import asynchttpserver, asyncdispatch, httpcore

type
  List[A] = ref object
    value: A
    next: List[A]
  StrPair* = tuple[k, v: string]
  # TODO: replace these by httpcore-HttpMethod
  Context* = object
    position*: int
    accept*: bool
    log*: ref string
    headers*: List[StrPair]


proc emptyList[A](): List[A] = nil

proc `+`[A](a: A, list: List[A]): List[A] =
  new result
  result.value = a
  result.next = list

iterator items*[A](list: List[A]): A =
  var node = list
  while node != nil:
    yield node.value
    node = node.next

proc reject*(ctx: Context): Context =
  Context(
    position: ctx.position,
    accept: false,
    log: ctx.log,
    headers: ctx.headers
  )

proc addPosition*(ctx: Context, n: int): Context =
  Context(
    position: ctx.position + n,
    accept: ctx.accept,
    log: ctx.log,
    headers: ctx.headers
  )

proc withPosition*(ctx: Context, n: int): Context =
  Context(
    position: n,
    accept: ctx.accept,
    log: ctx.log,
    headers: ctx.headers
  )

proc withLogging*(ctx: Context, s: ref string): Context =
  Context(
    position: ctx.position,
    accept: ctx.accept,
    log: s,
    headers: ctx.headers
  )

proc withHeaders*(ctx: Context, hs: openarray[StrPair]): Context =
  var headers = ctx.headers
  for h in hs:
    headers = h + headers
  return Context(
    position: ctx.position,
    accept: ctx.accept,
    log: ctx.log,
    headers: headers
  )

type Handler* = proc(req: ref Request, ctx: Context): Future[Context]

proc handle*(h: Handler): auto {.gcsafe.} =
  proc server(req: Request): Future[void] {.async, closure.} =
    let emptyCtx = Context(
      position: 0,
      accept: true,
      headers: emptyList[StrPair]()
    )
    var reqHeap = new(Request)
    reqHeap[] = req
    var
      f: Future[Context]
      ctx: Context
    try:
      f = h(reqHeap, emptyCtx)
      ctx = await f
    except:
      discard
    if f.failed:
      await req.respond(Http500, "Server Error", {"Content-Type": "text/plain;charset=utf-8"}.newHttpHeaders)
    else:
      if not ctx.accept:
        await req.respond(Http404, "Not Found", {"Content-Type": "text/plain;charset=utf-8"}.newHttpHeaders)

  return server

proc `~`*(h1, h2: Handler): Handler =
  proc h3(req: ref Request, ctx: Context): Future[Context] {.async.} =
    let newCtx = await h1(req, ctx)
    if newCtx.accept:
      return newCtx
    else:
      return await h2(req, ctx)

  return h3

proc `->`*(h1, h2: Handler): Handler =
  proc h3(req: ref Request, ctx: Context): Future[Context] {.async.} =
    let newCtx = await h1(req, ctx)
    if newCtx.accept:
      return await h2(req, newCtx)
    else:
      return newCtx

  return h3

template `[]`*(h1, h2: Handler): auto = h1 -> h2

proc serve*(server: AsyncHttpServer, port: Port, handler: Handler, address = ""): Future[void] =
  echo "My most dear lord!"
  echo "Rosencrantz ready on port ", port.int16
  serve(server, port, handle(handler), address)
