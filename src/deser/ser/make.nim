import std/[macros]

from ../magic/intermediate {.all.} import
  Struct,
  init

from ../magic/ser/generation {.all.} import
  generate


macro makeSerializable*(typ: varargs[typedesc], public: static[bool] = false) =
  result = newStmtList()

  for i in typ:
    var struct = Struct.init i
    
    result.add generate(struct, public)

  if defined(debugMakeSerializable):
    debugEcho result.toStrLit
