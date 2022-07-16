import std/[
  macros,
  strutils
]

from ../magic/intermediate {.all.} import 
  init

from ../magic/des/generation {.all.} import
  DeserStruct,
  flatten,
  generate


macro makeDeserializableStruct(typ: typed{`type`}, public: static[bool]) =
  var struct = DeserStruct.init typ
  struct.flattenFields = flatten struct.fields
  
  result = generate(struct, public)

  if defined(debugMakeDeserializable):
    debugEcho result.toStrLit


template makeDeserializable*(typ: typed{`type`}, public: static[bool] = false) {.dirty.} =
  bind makeDeserializableStruct

  when typ is object:
    makeDeserializableStruct(typ, public)
  else:
    {.error: "Unsupported type: `{$typ}`".}
