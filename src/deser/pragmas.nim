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


template defaultValue*(value: typed) {.pragma.} ##[
Uses the specified value if the field was not in the input

**Example**:

```nim
type
  User = object
    name {.defaultValue("noname").}: string
```
]##


template onUnknownKeys*(call: typed) {.pragma.} ##[
By default, the deserializer skips unknown fields.
You can change this behavior by specifying a template or procedure that will be called when an unknown field is detected.

The template or procedure must take two arguments:

the name of the object: string or static[string]

the field value: auto 

**Example**:

```nim
import std/[strformat]

# this example will not work with all parsers,
# because it expects the field as a string,
# but in some formats the field can be represented by a number
proc showUpdateWarning(objName, fieldName: string) =
  # show warning only once
  var yet {.global.} = false

  if not yet:
    echo &"An unknown `{fieldName}` field was detected when deseralizing the `{objName}` object. Check the library updates"
    yet = true


type
  User {.onUnknownKeys(showUpdateWarning).} = object
    id: int
    name: string
```

Another example with warnings output only once for each object:

```nim
proc showUpdateWarning(objName: static[string], fieldName: string) =
  # Since the object name is known at compile time,
  # we can make the `objName` argument generic and use the behavior of the `global` pragma
  # https://nim-lang.org/docs/manual.html#pragmas-global-pragma
  var yet {.global.} = false

  if not yet:
    echo &"An unknown `{fieldName}` field was detected when deseralizing the `{objName}` object. Check the library updates"
    yet = true
```
]##
