import strutils, sequtils, httpcore
import ./core, ./handlers, ./headersupport


proc accessControlAllowOrigin*(origin: string): auto =
  headers(("Access-Control-Allow-Origin", origin))

let accessControlAllowAllOrigins* = accessControlAllowOrigin("*")

proc accessControlExposeHeaders*(headers: openarray[string]): auto =
  headers(("Access-Control-Expose-Headers", headers.join(", ")))

proc accessControlMaxAge*(seconds: int): auto =
  headers(("Access-Control-Max-Age", $seconds))

proc accessControlAllowCredentials*(allow: bool): auto =
  headers(("Access-Control-Allow-Credentials", $allow))

proc accessControlAllowMethods*(methods: openarray[HttpMethod]): auto =
  headers(("Access-Control-Allow-Methods", methods.map(proc(m: auto): auto = $m).join(", ")))

proc accessControlAllowHeaders*(headers: openarray[string]): auto =
  headers(("Access-Control-Allow-Headers", headers.join(", ")))

proc accessControlAllow*(origin: string, methods: openarray[HttpMethod], headers: openarray[string]): auto =
  headers(
    ("Access-Control-Allow-Origin", origin),
    ("Access-Control-Allow-Methods", methods.map(proc(m: auto): auto = $m).join(", ")),
    ("Access-Control-Allow-Headers", headers.join(", "))
  )

proc stringToMethod(s: string): HttpMethod =
  case s.toUpper
  of "GET": return HttpGet
  of "POST": return HttpPost
  of "PUT": return HttpPut
  of "DELETE": return HttpDelete
  of "HEAD": return HttpHead
  of "PATCH": return HttpPatch
  of "OPTIONS": return HttpOptions
  of "TRACE": return HttpTrace
  of "CONNECT": return HttpConnect
  else: raise newException(ValueError, "Unknown method name")

proc readAccessControl*(p: proc(origin: string, m: HttpMethod, headers: seq[string]): Handler): Handler =
  tryReadHeaders("Origin", "Access-Control-Allow-Method", "Access-Control-Allow-Headers", proc(s1, s2, s3: string): Handler =
    try:
      return p(s1, stringToMethod(s2), s3.split(","))
    except:
      return reject()
  )