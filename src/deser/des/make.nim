import std/[
  macros
]

from ../magic/intermediate {.all.} import 
  init

from ../magic/des/generation {.all.} import
  DeserStruct,
  flatten,
  generate


macro makeDeserializable*(typ: varargs[typedesc], public: static[bool] = false) =
  result = newStmtList()

  for i in typ:
    var struct = DeserStruct.init i
    struct.flattenFields = flatten struct.fields
    
    result.add generate(struct, public)

  if defined(debugMakeDeserializable):
    debugEcho result.toStrLit
