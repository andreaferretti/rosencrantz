import asynchttpserver, asyncdispatch, asyncfutures, asyncnet, asyncstreams,
  httpcore, os, strutils, tables
import ./core, ./handlers

proc sendChunk*(req: ref Request, s: string): Future[void] {.async.} =
  var chunk = s.len.toHex
  chunk.add("\c\L")
  chunk.add(s)
  chunk.add("\c\L")
  await req[].client.send(chunk)

proc streaming*(fs: FutureStream[string], contentType = "text/plain"): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    let code = Http200
    var hs = {"Content-Type": contentType}.newHttpHeaders
    # Should traverse in reverse order
    for h in ctx.headers:
      hs[h.k] = h.v
    if not ctx.log.isNil:
      debugEcho ctx.log[].format(req.reqMethod, req.url.path, req.headers.table, req.body, code, hs.table)
    var start = "HTTP/1.1 " & $code & "\c\L"
    await req[].client.send(start)
    await req[].sendHeaders(hs)
    await req[].client.send("Transfer-Encoding: Chunked\c\L\c\L")
    while not finished(fs):
      let (moreData, chunk) = await fs.read()
      if moreData:
        await req.sendChunk(chunk)
      else:
        await req.sendChunk("")
        break
    return ctx

  return h