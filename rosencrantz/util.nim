import strtabs, strutils

proc parseUrlencoded*(body: string): StringTableRef {.inline.} =
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