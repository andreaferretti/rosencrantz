import asynchttpserver, asyncdispatch, httpcore, sequtils, json, random, rosencrantz

type Todo = object
  title: string
  completed: bool
  url: string
  order: int

proc `%`(todo: Todo): JsonNode =
  %{"title": %(todo.title), "completed": %(todo.completed), "url": %(todo.url),
    "order": %(todo.order)}

proc `%`(todos: seq[Todo]): JsonNode = %(todos.map(`%`))

template renderToJson(x: auto): JsonNode = %x

proc makeUrl(n: int): string = "http://localhost:8080/todos/" & $n

proc parseFromJson(j: JsonNode, m: typedesc[Todo]): Todo =
  let
    title = j["title"].getStr
    completed = if j.hasKey("completed"): j["completed"].getBool else: false
    url = if j.hasKey("url"): j["url"].getStr else: rand(1000000).makeUrl
    order = if j.hasKey("order"): j["order"].getInt else: 0
  return Todo(title: title, completed: completed, url: url, order: order)

proc merge(todo: Todo, j: JsonNode): Todo =
  let
    title = if j.hasKey("title"): j["title"].getStr else: todo.title
    completed = if j.hasKey("completed"): j["completed"].getBool else: todo.completed
    url = if j.hasKey("url"): j["url"].getStr else: todo.url
    order = if j.hasKey("order"): j["order"].getInt else: todo.order
  return Todo(title: title, completed: completed, url: url, order: order)

var todos: seq[Todo] = @[]

let handler = accessControlAllow(
  origin = "*",
  headers = ["Content-Type"],
  methods = [HttpGet, HttpPost, HttpDelete, HttpPatch, HttpOptions]
)[
  get[
    path("/todos")[
      scope do:
        return ok(todos)
    ] ~
    pathChunk("/todos")[
      intSegment(proc(n: int): auto =
        let url = makeUrl(n)
        for todo in todos:
          if todo.url == url: return ok(todo)
        return notFound()
      )
    ]
  ] ~
  post[
    path("/todos")[
      jsonBody(proc(todo: Todo): auto =
        todos.add(todo)
        return ok(todo)
      )
    ]
  ] ~
  rosencrantz.delete[
    path("/todos")[
      scope do:
        todos = @[]
        return ok(todos)
    ] ~
    pathChunk("/todos")[
      intSegment(proc(n: int): auto =
        let url = makeUrl(n)
        for i, todo in todos:
          if todo.url == url:
            todos.delete(i)
            return ok(todo)
      )
    ]
  ] ~
  patch[
    pathChunk("/todos")[
      intSegment(proc(n: int): auto =
        jsonBody(proc(j: JsonNode): auto =
          let url = makeUrl(n)
          for i, todo in todos:
            if todo.url == url:
              let updatedTodo = todo.merge(j)
              todos[i] = updatedTodo
              return ok(updatedTodo)
          return notFound()
        )
      )
    ]
  ] ~
  options[ok("")]
]

let server = newAsyncHttpServer()

waitFor server.serve(Port(8080), handler)