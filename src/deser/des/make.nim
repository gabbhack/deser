import std/macros

import ../private/parse {.all.}
import ../private/des {.all.}


macro makeDeserializableStruct(typ: typed{`type`}, public: static[bool]) =
  var struct = DeserStruct.init typ
  struct.flattenFields = flatten struct.fields
  
  result = generate(struct, public)

  if defined(debugMakeDeserializable):
    debugEcho result.toStrLit


template makeDeserializable*(typ: typed{`type`}, public: static[bool] = false) {.dirty.} =
  bind makeDeserializableStruct

  when type is object:
    makeDeserializableStruct(typ, public)
