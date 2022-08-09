import std/[
  macros
]

from ../magic/intermediate {.all.} import 
  init

from ../magic/des/generation {.all.} import
  DeserStruct,
  flatten,
  generate


macro makeDeserializable*(typ: typed{`type`}, public: static[bool] = false) =
  var struct = DeserStruct.init typ
  struct.flattenFields = flatten struct.fields
  
  result = generate(struct, public)

  if defined(debugMakeDeserializable):
    debugEcho result.toStrLit
