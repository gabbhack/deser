import std/macros

import ../private/parse {.all.}
import ../private/des {.all.}


macro makeDeserializableStruct(typ: typed{`type`}, public: static[bool]) =
  var struct = DeserStruct.init typ
  struct.flattenFields = flatten struct.fields
  
  result = generate(struct, public)

  if defined(debugMakeDeserializable):
    debugEcho result.toStrLit


template makeDeserializableEnum(typ: enum, public: static[bool]) = discard


template makeDeserializable*(typ: typed{`type`}, public: static[bool] = false) {.dirty.} =
  bind makeDeserializableStruct

  when typ is enum:
    discard
  else:
    makeDeserializableStruct(typ, public)
