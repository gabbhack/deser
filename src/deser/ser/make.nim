import std/[macros]

from ../magic/intermediate {.all.} import
  Struct,
  init

from ../magic/ser/generation {.all.} import
  generate


macro makeSerializable*(typ: varargs[typedesc], public: static[bool] = false) = ##[
Generate `serialize` procedure for your type. Use `public` parameter to export.

Works only for objects and ref objects.

Compile with `-d:debugMakeSerializable` to see macro output.

**Example**:
```nim
makeSerializable(Foo)

# Use array of types if you want to make deserializable many types
makeSerializable([
  Foo,
  Bar
])
```
]##
  result = newStmtList()

  for i in typ:
    var struct = Struct.init i
    
    result.add generate(struct, public)

  if defined(debugMakeSerializable):
    debugEcho result.toStrLit
