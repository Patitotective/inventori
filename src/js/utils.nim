import std/[strutils, dom]

proc couldBeInt*(f: float): bool = f.int.float == f

proc quoted*(x: string): string = result.addQuoted(x)

proc getPosition(event: MouseEvent): tuple[x, y: int] =
  let event = if event.isNil: MouseEvent(window.event) else: event

  if event.pageX != 0 or event.pageY != 0:
    result = (event.pageX, event.pageY)
  elif event.clientX != 0 or event.clientY != 0:
    result = (event.clientX + document.body.scrollLeft + document.documentElement.scrollLeft,
      event.clientY + document.body.scrollTop + document.documentElement.scrollTop)

proc calcMenuPos*(id: string, event: MouseEvent): tuple[x, y: int] =
  let pos = getPosition(event)
  let menu = getElementById(cstring id)

  let menuWidth = menu.offsetWidth + 4
  let menuHeight = menu.offsetHeight + 4

  result.x =
    if window.innerWidth - pos.x < menuWidth:
      window.innerWidth - menuWidth
    else: pos.x

  result.y =
    if window.innerHeight - pos.y < menuHeight:
      window.innerHeight - menuHeight
    else: pos.y

proc contains*(a, b: dom.Node): bool {.importjs: "contains(@)".}

proc trim*(s: cstring): cstring {.importjs: "trim(#)"}

# TODO: change appName
proc makeUri*(relative: string, appName = "/", includeHash = false, search: string = ""): string =
  ## Concatenates ``relative`` to the current URL in a way that is
  ## (possibly) sane.
  var relative = relative
  assert appName in $window.location.pathname
  if relative[0] == '/': relative = relative[1..^1]

  return $window.location.protocol & "//" &
          $window.location.host &
          appName &
          relative &
          search &
          (if includeHash: $window.location.hash else: "")


proc navigateTo*(uri: cstring) =
  # TODO: This was annoying. Karax also shouldn't have its own `window`.
  dom.pushState(dom.window.history, 0, cstring"", uri)

  # Fire the popState event.
  dom.dispatchEvent(dom.window, dom.newEvent("popstate"))


