import tables, strtabs, strutils

proc parseUrlEncoded*(body: string): StringTableRef {.inline.} =
  result = {:}.newStringTable
  for s in body.split('&'):
    if s.len == 0 or s == "=":
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

proc parseUrlEncodedMulti*(body: string): TableRef[string, seq[string]] {.inline.} =
  new result
  result[] = initTable[string, seq[string]]()
  template add(k, v: string) =
    if result.hasKey(k):
      result.mget(k).add(v)
    else:
      result[k] = @[v]

  for s in body.split('&'):
    if s.len == 0 or s == "=":
      add("", "")
    else:
      let
        i = s.find('=')
        h = s.high()
      if i == -1:
        add(s, "")
      elif i == 0:
        add("", s[i+1 .. h])
      elif i == h:
        add(s[0 .. h-1], "")
      else:
        add(s[0 .. i-1], s[i+1 .. h])