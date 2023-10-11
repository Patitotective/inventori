import std/tables
import std/dom except Node

type
  Attribute* = object
    name*: string
    values*: seq[tuple[val: string, price: int]]

  Item* = object

  Kind* = object
    name*: string
    #icon*: Rune # emoji??
    attributes*: seq[Attribute]
    totalQuantity*: int
    basePrice*: int
    items*: seq[Item]

  Inventory* = seq[Kind]

type
  ContextMenu* = object
    show*: bool
    pos*: tuple[x, y: int]
    actions*: seq[(string, proc())]

  Locale* = enum
    En, Es, Ja

  State* = object
    lang*: Locale
    url*: Location
    originalTitle*: cstring
    baseTitle*: string # all page titles will be &"baseTitle - {other}"
    appName*: string # base URL pathname for the app (default /)
    editable*: bool # any editableText with display is being edited?
    tempNode*: dom.Node # github.com/karaxnim/karax/issues/262
    contextmenu*: ContextMenu
    confirmId*: cstring # The Id of a button that needs confirmation (click again)

    inventory*: Inventory
