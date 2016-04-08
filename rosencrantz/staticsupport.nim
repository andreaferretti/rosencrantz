import asynchttpserver, asyncdispatch, asyncfile, strtabs, os
import rosencrantz/core, rosencrantz/handlers


proc file*(path: string): Handler =
  let f = openAsync(path)
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    f.setFilePos(0)
    let content = await f.readAll
    var hs = {"Content-Type": "text/plain"}.newStringTable
    # Should traverse in reverse order
    for h in ctx.headers:
      hs[h.k] = h.v
    await req[].respond(Http200, content, hs)
    return ctx

  return h

proc dir*(path: string): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    template p: auto = req.url.path

    let
      fileName = p[ctx.position .. p.high]
      completeFileName = path / fileName
      f = openAsync(completeFileName)
    let content = await f.readAll
    close(f)
    var hs = {"Content-Type": "text/plain"}.newStringTable
    # Should traverse in reverse order
    for h in ctx.headers:
      hs[h.k] = h.v
    await req[].respond(Http200, content, hs)
    return ctx

  return h