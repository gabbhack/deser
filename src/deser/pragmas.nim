template untagged*() {.pragma.} ##[
By default, the discriminant of object variants is de/serialized as a regular field:

```nim
type
  Test = object
    kind: bool
    of true:
      trueField: string
    else:
      falseField: string
```
equals to this JSON:

```
{
  "kind": true
  "trueField": ""
}
```

However, `deser` can independently deduce the discriminant from the raw data:

```nim
type
  Test = object
    kind {.untagged.}: bool
    of true:
      trueField: string
    else:
      falseField: string

const js = """
  {
    "trueField": ""
  }
let test = Test.fromJson(js)

assert test.kind
```


]##

template serializeWith*(with: typed) {.pragma.} ##[
Serialize this field using a procedure.
The given function must be callable as `proc[Serializer] (self: field.type, serializer: var Serializer)`
]##

template renamed*(renamed: string) {.pragma.} ##[
Serialize and deserialize field with the given name instead of its Nim name
]##

template renameSerialize*(renamed: string) {.pragma.} ##[
Serialize field with the given name instead of its Nim name
]##

template renameDeserialize*(renamed: string) {.pragma.} ##[
Deserialize field with the given name instead of its Nim name
]##

template skipped*() {.pragma.} ##[
Use this pragma to skip the field during serialization and deserialization.

**Example**:

```nim
type
  Test = object
    alwaysSkip {.skipped.}: int
```
]##

template skipSerializing*() {.pragma.} ##[
Use this pragma to skip the field during serialization.

**Example**:
```nim
type
  Test = object
    skipOnSerialization {.skipSerializing.}: int
```
]##

template skipDeserializing*() {.pragma.} ##[
Use this pragma to skip the field during deserialization.

**Example**:

```nim
type
  Test = object
    skipOnDeserialization {.skipDeserializing.}: int
```
]##

template skipSerializeIf*(condition: typed) {.pragma.} ##[
Use this pragma to skip the field during serialization based on the runtime value.
You must specify a function or template that accepts an argument with the same type as the field, and return bool.

**Example**:
  
```nim
import options

func isZero(x: int) = x == 0

type
  Test = object
    someOption {.skipSerializeIf(isNone).}: Option[int]
    someInt {.skipSerializeIf(isZero).}: int
```
]##


# TODO future
template defaultValue*(value: typed) {.pragma.} ##[
Uses the specified value if the field was not in the input

**Example**:

```nim
type
  User = object
    name {.defaultValue("noname").}: string
```
]##
