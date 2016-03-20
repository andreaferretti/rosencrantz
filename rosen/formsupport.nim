import strtabs, strutils, asynchttpserver, asyncdispatch
import rosen/core

proc parseUrlencoded(body: string): StringTableRef {.inline.} =
  result = {:}.newStringTable
  for s in body.split('&'):
    if s.len() == 0 or s == "=":
      result[""] = ""
    else:
      let
        i = s.find('=')
        h = s.high()
      if i == -1:
        result[s] = ""
      elif i == 0:
        result[""] = s[i+1 .. h]
      elif i == h:
        result[s[0 .. h-1]] = ""
      else:
        result[s[0 .. i-1]] = s[i+1 .. h]

proc formBody*(p: proc(s: StringTableRef): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    var s: StringTableRef
    try:
      s = req.body.parseUrlencoded
    except:
      return ctx.reject()
    let handler = p(s)
    let newCtx = await handler(req, ctx)
    return newCtx

  return h