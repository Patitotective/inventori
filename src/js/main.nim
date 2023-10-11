import std/[strformat, strutils, sugar, uri]
import std/jsffi except `&`
import karax/[jstrutils, vstyles, karaxdsl, karax, kbase, kdom]
import urlly
#import kdl

import vdom
import translations, routes, utils
import types except Node

# TODO: add collapsable sections separating kinds and items

const
  errorSVG = """<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6">
  <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
</svg>
"""

proc `$`(s: cstring): string =
  when defined(release):
    {.error: "not for release".}

  if s.isNil:
    "nil"
  else:
    system.`$`(s)

proc setLang(state: var State, lang: string) =
  try:
    state.lang = parseEnum[Locale](lang.capitalizeAscii)
    document.documentElement.setAttr("lang", lang)
  except ValueError:
    echo "invalid locale ", lang

proc focus(id: string or kstring) =
  discard setTimeOut(() => getElementById(id).focus(), 0) # Otherwise it doesn't actually focus the content editable

# Render a contentedtiable=true span
proc renderEditableText(state: var State, id: string, text: string, display = "", stripInput = true, acceptOrReject: proc(oldval, newval: string): bool = nil, onaccept: proc(oldval, newval: string) = nil, onreject: proc(val: string) = nil): VNode =
  buildHtml:
    # Here we set a minWidth because otherwise when empty it becomes zero width
    span(id = cstring id, style = "minWidth: 15px".toCss, class = "inline-block", contenteditable = display.len == 0 or state.editable):
      if display.len > 0:
        text display
      else:
        text text

      proc onclick(_: Event, node: VNode) =
        if display.len > 0 and not state.editable:
          # Here we replace the dom node's text with the actual text and not the display text (to switch between a formula's result and the formula itself for example)
          let element = getElementById(node.id)
          element.childNodes[0].nodeValue = text
          node[0].text = kstring text

          state.editable = true

        focus(node.id)

      proc onblur(event: Event, node: VNode) =
        let element = getElementById(node.id)
        # Here we use the javascript trim function instead of the nim strip procedure since javascript strings have some weird characters at the begininning (e.g.: no-breaking-space)
        let newval = if stripInput: $trim(element.textContent) else: $element.textContent

        if newval.len > 0 and text != newval and (acceptOrReject.isNil or acceptOrReject(text, newval)):
          if not onaccept.isNil: onaccept(text, newval)
          if not kxi.surpressRedraws: redraw(kxi)
        else:
          # vdom -> dom; update dom with vdom value
          element.childNodes[0].nodeValue = cstring(if display.len > 0: display else: text)

          if not onreject.isNil: onreject(newval)

        state.editable = false

      proc onbeforeinput(event: Event, node: VNode) = # github.com/karaxnim/karax/issues/262
        let element = getElementById(node.id)

        if element.childNodes.len == 1:
          state.tempNode = element.childNodes[0]

      proc oninput(event: Event, node: VNode) = # github.com/karaxnim/karax/issues/262
        let element = getElementById(node.id)

        if element.len == 0:
          state.tempNode.data = ""
          element.appendChild(state.tempNode)

        # echo (ele: element.childNodes[0].nodeValue, node: node[0].text)
        # echo (ele: element.len, node: node.len, renode: node.dom.len)
        # echo (ele: element.className, node: node.kind)

      proc onkeydown(event: Event, node: VNode) =
        let element = getElementById(node.id)

        case $KeyboardEvent(event).key
        of "Enter":
          event.preventDefault()
          element.blur()
        of "Escape":
          event.preventDefault()
          element.childNodes[0].nodeValue = "" # Here we ensure that the value is going to get rejected
          element.blur()
        else:
          discard

# Render a generic context menu that uses data from state.contextmenu to get the actions
proc renderContextmenu(state: var State): VNode =
  # Wrap every action precedure so it closes the context menu after it
  proc click(action: proc()): auto =
    proc() =
      action()
      state.contextmenu.show = false

  buildHtml tdiv(id = "contextmenu", style = toCss &"top: {state.contextmenu.pos.y}px; left: {state.contextmenu.pos.x}px;", class = cstring &"absolute z-10 bg-white border p-2 text-sm {(if state.contextmenu.show: \"block\" else: \"hidden\")}"):
    ul:
      for (name, action) in state.contextmenu.actions:
        li(class = "clickable", onclick = click(action)):
          text name

proc renderSidebar(state: var State): VNode =
  proc click(item: string): auto =
    proc(event: Event, node: VNode) =
      echo &"onclick {item}"
      navigateTo(cstring makeUri('/' & item))

  buildHtml aside(id = "sidebar", class = "fixed top-0 left-0 z-40 w-64 h-screen"):
    tdiv(class = "h-full px-3 py-4 overflow-y-auto bg-gray-50"):
      ul(class = "space-y-2 font-medium"):
        for i in ["inventory", "sales", "settings"]:
          li:
            button(class="flex items-center p-2 text-gray-900 rounded-lg hover:bg-gray-100 group", onclick = click(i)):
              text i

              # span(class = "ml-3"):
                # text i

proc renderInventoryTab(state: var State): VNode =
  buildHtml tdiv(id = "inventory", class = "p-4 sm:ml-64"):
    for kind in state.inventory:
      tdiv(class = "p-2 text-gray-800 rounded-lg hover:bg-gray-100 group"):
        span:
          text kind.name

        span(class = "items-right"):
          text &"{kind.totalQuantity} {state.lang.items}"

    button(class = "text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 mr-2 mb-2"):
      text state.lang.addItem

      proc onclick(event: Event, node: VNode) =
        

proc renderSalesTab(state: var State): VNode =
  document.title = cstring &"{state.baseTitle} - sales"
  buildHtml tdiv(id = "sales"):
    discard

proc renderSettingsTab(state: var State): VNode =
  document.title = cstring &"{state.baseTitle} - settings"
  buildHtml tdiv(id = "settings"):
    discard

proc render(state: var State): VNode =
  dom.document.title = cstring state.baseTitle
  buildHtml tdiv(class = "w-full h-full"):
    # We draw this contextmenu always but only show it state.showContextmenu is true
    # Then we use data from state.contextmenu to change the actions
    renderContextmenu(state)

    proc onmousedown(event: Event, _: VNode) =
      # Close context menu if clicked (with any button) outside of the context menu
      if state.contextmenu.show and not getElementById("contextmenu").contains(event.target):
        state.contextmenu.show = false

      # Empty confirmId if you click outside it
      if state.confirmId.len > 0 and not getElementById(state.confirmId).contains(event.target):
        state.confirmId = ""

    state.renderSidebar()

    state.route([
      r("/inventory", (params: Params) => state.renderInventoryTab()),
      r("/sales", (params: Params) => state.renderSalesTab()),
      r("/settings", (params: Params) => state.renderSettingsTab()),
    ])

    #tdiv(id = "docs"):
    #  for idx in state.docs.low..state.docs.high:
    #    state.renderDocument(idx)

    #tdiv(id = "buttons", class = "space-x-2"):
    #  button(class = "clickable"):
    #    text state.lang.createDoc

    #    proc onclick() =
    #      state.docs.add(default Doc)

    #  button(class = "clickable"):
    #    text state.lang.exportDoc

    #    proc onclick() =
    #      echo "TODO: export"
    #      # window.alert(cstring state.docs.pretty(newLine = false))

    #  button(class = "clickable"):
    #    text state.lang.importDoc

    #    proc onclick() =
    #      echo "TODO: import"

    #      state.modal.open()
    #      #if (let input = window.prompt("enter kdl doc", ""); not input.isNil):
    #        #discard state.asyncAddDocument asyncImportKdl($input)

proc parseUrl(state: var State) =
  for (key, val) in decodeQuery($state.url.search):
    case key
    of "l": # language
      state.setLang(val)

proc copyLocation(loc: Location): Location = # Copied from https://github.com/nim-lang/nimforum/blob/master/src/frontend/forum.nim
  # TODO: It sucks that I had to do this. We need a nice way to deep copy in JS.
  Location(
    hash: loc.hash,
    host: loc.host,
    hostname: loc.hostname,
    href: loc.href,
    pathname: loc.pathname,
    port: loc.port,
    protocol: loc.protocol,
    search: loc.search
  )

proc newState(): State =
  State(
    appName: "/",
    url: window.location.copyLocation(),
    originalTitle: document.title,
    baseTitle: "inventori"
  )

proc onPopState(state: var State): proc =
  proc (event: dom.Event) = # Copied from https://github.com/nim-lang/nimforum/blob/master/src/frontend/forum.nim
    # This event is usually only called when the user moves back in their
    # history. I fire it in karaxutils.anchorCB as well to ensure the URL is
    # always updated. This should be moved into Karax in the future.
    echo "New URL: ", window.location.href, " ", state.url.href
    document.title = state.originalTitle
    if state.url.href != window.location.href:
      state = newState() # Reload the state to remove stale data.
    state.url = copyLocation(window.location)

    redraw()

proc main() =
  var state = newState()

  # Process queries (?l=es&i=a 1)
  state.parseUrl()

  # Keybinds for the whole page
  document.body.addEventListener("keyup", proc(event: Event) =
    case $KeyboardEvent(event).key
    of "|":
      echo state
    of "+":
      discard
    else: discard
  )

  window.onPopState = onPopState(state)
  setRenderer () => state.render()

main()
