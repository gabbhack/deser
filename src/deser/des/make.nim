import std/[
  macros
]

from ../magic/intermediate {.all.} import
  Struct,
  init

from ../magic/des/generation {.all.} import
  generate


macro makeDeserializable*(typ: varargs[typedesc], public: static[bool] = false) =
  ##[
Generate `deserialize` procedure for your type. Use `public` parameter to export.

Works only for objects and ref objects.

Compile with `-d:debugMakeDeserializable` to see macro output.

**Example**:
```nim
makeDeserializable(Foo)

# Use array of types if you want to make deserializable many types
makeDeserializable([
  Foo,
  Bar
])
```
]##
  result = newStmtList()

  for i in typ:
    var struct = Struct.init i
    
    result.add generate(struct, public)

  if defined(debugMakeDeserializable):
    debugEcho result.toStrLit
