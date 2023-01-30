import std/[
  macros
]

from deser/macroutils/types import
  Struct

from deser/macroutils/parsing/struct import
  fromTypeSym

from deser/macroutils/generation/des import
  defDeserialize


macro makeDeserializable*(types: varargs[typedesc], public: static[bool] = false) =
  ##[
Generate `deserialize` procedure for your type. Use `public` parameter to export.

Works only for objects and ref objects.

Compile with `-d:debugMakeDeserializable` to see macro output.
Compile with `-d:debugMakeDeserializableTree` to see macro output as NimNode tree.

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

  for typeSym in types:
    var struct = Struct.fromTypeSym(typeSym)
    
    result.add defDeserialize(struct, public)

  if defined(debugMakeDeserializable):
    debugEcho result.toStrLit
  
  if defined(debugMakeDeserializableTree):
    debugEcho result.treeRepr
