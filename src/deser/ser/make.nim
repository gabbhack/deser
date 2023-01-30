import std/[
  macros
]

from deser/macroutils/types import
  Struct

from deser/macroutils/parsing/struct import
  fromTypeSym

from deser/macroutils/generation/ser import
  defSerialize


macro makeSerializable*(types: varargs[typedesc], public: static[bool] = false) = ##[
Generate `serialize` procedure for your type. Use `public` parameter to export.

Works only for objects and ref objects.

Compile with `-d:debugMakeSerializable` to see macro output.
Compile with `-d:debugMakeSerializableTree` to see macro output as NimNode tree.

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

  for typeSym in types:
    var struct = Struct.fromTypeSym(typeSym)
    
    result.add defSerialize(struct, public)

  if defined(debugMakeSerializable):
    debugEcho result.toStrLit

  if defined(debugMakeSerializableTree):
    debugEcho result.treeRepr
