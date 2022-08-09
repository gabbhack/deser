import std/[
  macros
]

from ../magic/intermediate {.all.} import
  Struct,
  init

from ../magic/des/generation {.all.} import
  generate


macro makeDeserializable*(typ: varargs[typedesc], public: static[bool] = false) =
  result = newStmtList()

  for i in typ:
    var struct = Struct.init i
    
    result.add generate(struct, public)

  if defined(debugMakeDeserializable):
    debugEcho result.toStrLit
