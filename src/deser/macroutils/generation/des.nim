import std/[
  macros
]

import des/[
  keys,
  values
]

export
  keys,
  values

from deser/macroutils/types import
  Struct


func defDeserialize*(struct: Struct, public: bool): NimNode =
  let
    fieldVisitor = genSym(nskType, "FieldVisitor") 
    valueVisitor = genSym(nskType, "Visitor")

  newStmtList(
    defKeyDeserialize(fieldVisitor, struct, public),
    defValueDeserialize(valueVisitor, struct, public),
  )
