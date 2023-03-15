type
  RenameCase* = enum
    CamelCase
    CobolCase
    KebabCase
    PascalCase
    PathCase
    SnakeCase
    PlainCase
    TrainCase
    UpperSnakeCase


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

```json
{
  "kind": true
  "trueField": ""
}
```

However, `deser` can deduce the discriminant from the raw data:

```nim
import deser_json

type
  Test = object
    kind {.untagged.}: bool
    of true:
      trueField: string
    else:
      falseField: string

makeDeserializable(Test)

const json = """
  {
    "trueField": ""
  }
"""
let test = Test.fromJson(json)

assert test.kind == true
```
]##

template serializeWith*(with: typed) {.pragma.} ##[
Serialize this field using a procedure.

The given function must be callable as `proc (self: FieldType, serializer: var auto)`.

**Example:**
```nim
import std/times

import
  deser,
  deser_json

proc toTimestamp(self: Time, serializer: var auto) =
  serializer.serializeInt64(self.toUnix())

type
  User = object
    created {.serializeWith(toTimestamp).}: Time

makeSerializable(User)

assert User(created: fromUnix(123)).toJson() == """{"created":123}"""
```
]##

template deserializeWith*(with: typed) {.pragma.} ##[
Deserialize this field using a procedure.

The given procedure must be callable as `proc (deserializer: var auto): FieldType` or `proc [T](deserializer: var auto): T`.

**Example:**
```nim
import std/times

import
  deser,
  deser_json

proc fromTimestamp(deserializer: var auto): Time =
  fromUnix(deserialize(int64, deserializer))

type
  User = object
    created {.deserializeWith(fromTimestamp).}: Time

makeDeserializable(User)

assert User(created: fromUnix(123)) == User.fromJson("""{"created": 123}""")
```
]##

template deserWith*(with: typed) {.pragma.} ##[
Combination of `serializeWith` and `deserializeWith`.

The given type (or anything actually) must have callable .serialize and .deserialize attributes.

.serialize must be callable as `proc (self: withType, field: FieldType, serializer: var auto)`.

.deserialize must be callable as `proc (self: withType, deserializer: var auto): FieldType` or `proc [T](self: withType, deserializer: var auto): T`.

**Example:**
```nim
import std/times

import
  deser,
  deser_json


type UnixTimeFormat = object

proc deserialize(self: typedesc[UnixTimeFormat], deserializer: var auto): Time =
  fromUnix(deserialize(int64, deserializer))

proc serialize(self: typedesc[UnixTimeFormat], field: Time, serializer: var auto) =
  serializer.serializeInt64(self.toUnix())

type
  User = object
    created {.deserWith(UnixTimeFormat).}: Time

makeSerializable(User)
makeDeserializable(User)

let user = User(created: fromUnix(123))

assert user == User.fromJson("""{"created": 123}""")
assert user.toJson() == """{"created":123}"""
```
]##

template renamed*(renamed: string | RenameCase) {.pragma.} ##[
Serialize and deserialize field with the given name instead of its Nim name.
]##

template renameSerialize*(renamed: string | RenameCase) {.pragma.} ##[
Serialize field with the given name instead of its Nim name.
]##

template renameDeserialize*(renamed: string | RenameCase) {.pragma.} ##[
Deserialize field with the given name instead of its Nim name.
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
import std/options

func isZero(x: int): bool = x == 0

type
  Test = object
    someOption {.skipSerializeIf(isNone).}: Option[int]
    someInt {.skipSerializeIf(isZero).}: int
```
]##

template defaultValue*(value: typed = nil) {.pragma.} ##[
Uses the specified value if the field was not in the input.

**Example**:

```nim
type
  User = object
    name {.defaultValue("noname").}: string
```

Do not specify a value, then `default(FieldType)` will be used

```nim
import deser_json

type
  Foo = object
    id {.defaultValue.}: int

assert Foo.fromJson("""{}""").id == 0
```
]##

template onUnknownKeys*(call: typed) {.pragma.} ##[
By default, the deserializer skips unknown fields.
You can change this behavior by specifying a template or procedure that will be called when an unknown field is detected.

The template or procedure must take two arguments:

- the name of the object: string or static[string]

- the field value: auto 

**Example**:

```nim
import std/strformat

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

template renameAll*(renameTo: RenameCase) {.pragma.} ##[
Rename all fields to some case.

.. Note:: Pragma respects other `rename` pragmas. For example, if a field has the `renameSerialize` pragma, only deserialization will be affected.

**Example**:
```nim
import deser_json

type
  Foo {.renameAll(SnakeCase).} = object
    firstName: string
    lastName: string

makeSerializable(Foo)

assert Foo().toJson() == """{"first_name":"","last_name":""}"""
```
]##

template skipPrivateSerializing* {.pragma.} ##[
Use this pragma to skip all private fields during serialization

**Example**:
```nim
type
  User {.skipPrivateSerializing.} = object
    id*: int
    name*: string
    passwordHash: string
```
]##

template skipPrivateDeserializing* {.pragma.} ##[
Use this pragma to skip all private fields during deserialization

**Example**:
```nim
type
  User {.skipPrivateDeserializing.} = object
    id*: int
    name*: string
    passwordHash: string
```
]##

template skipPrivate* {.pragma.} ##[
Use this pragma to skip all private fields during serialization and deserialization.

**Example**:
```nim
type
  User {.skipPrivate.} = object
    id*: int
    name*: string
    passwordHash: string
```
]##  

template aliases*(aliases: varargs[typed]) {.pragma.} ##[
Deserialize field from the given names or from its Nim name.
Accepts strings and `RenameCase` values.

**Example**:
```nim
type
  User = object
    nickName {.aliases("username", "login", SnakeCase).}: string
```
]##
