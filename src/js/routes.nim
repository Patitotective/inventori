import std/tables
import jester/patterns
import types, vdom

type
  Params* = Table[string, string]
  Route* = object
    name*: string
    renderProc*: proc (params: Params): VNode

proc r*(name: string, renderProc: proc (params: Params): VNode): Route =
  Route(name: name, renderProc: renderProc)

proc route*(state: State, routes: openarray[Route]): VNode =
  let path = if state.url.pathname.len == 0: "/" else: $state.url.pathname
  let prefix = if state.appName == "/": "" else: state.appName
  for route in routes:
    let pattern = (prefix & route.name).parsePattern()
    var (matched, params) = pattern.match(path)
    # parseUrlQuery($state.url.search, params) # TODO
    if matched:
      return route.renderProc(params)

  # return renderError("Unmatched route: " & path, Http500) # TODO

