import macros

# macro scope*(body: untyped): untyped =
#  if kind(body) != nnkDo: body
#  else: newBlockStmt(body[6])

template scope*(body: untyped): untyped =
  proc inner: auto {.gensym.} = body
  inner()