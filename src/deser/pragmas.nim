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

template renameSerialize*(renamed: string) {.pragma.} ##[
Serialize this field with the given name instead of its Nim name
]##

template renameDeserialize*(renamed: string) {.pragma.} ##[
Deserialize this field with the given name instead of its Nim name
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

template inlineKeys*() {.pragma.} ##[
Use this pragma to inline keys from the field into the parent object.

**Example**:

```nim
type
  Pagination = object
    limit: uint64
    offset: uint64
    total: uint64
  
  Users = object
    users: seq[User]
    pagination {.inlineKeys.}: Pagination
```

equals to this JSON:

```
{
  "users": [],
  "limit": 10,
  "offset": 10,
  "total": 10
}
```
]##
