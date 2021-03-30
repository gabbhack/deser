type
  RenameKind* = enum
    ##[
    Variants of cases.

    **rkNothing** - The default value in `renameAll <pragmas.html>`_. The name will not be changed.

    **rkCamelCase** - Any to camelCase.

    **rkSnakeCase** - Any to snake_case.

    **rkKebabCase** - Any to kebab-case.

    **rkPascalCase** - Any to PascalCase.

    **rkUpperSnakeCase** - Any to SNAKE_CASE.

    **rkUpperKebabCase** - Any to KEBAB-CASE
    ]##
    rkNothing,
    rkCamelCase,
    rkSnakeCase,
    rkKebabCase,
    rkPascalCase,
    rkUpperSnakeCase,
    rkUpperKebabCase

template des*() {.pragma.} ##[
**Only for objects, compile-time**

Use this pragma to mark an object as deserializable.

**Example**:
```nim
type
  Test {.des.} = object
    id: int
```
]##

template ser*() {.pragma.} ##[
**Only for objects, compile-time**

Use this pragma to mark an object as serializable.

**Example**:
```nim
type
  Test {.ser.} = object
    id: int
```
]##

# ISSUE: https://github.com/nim-lang/Nim/issues/16158
template rename*(ser = "", des = "") {.pragma.} ##[
**Only for fields, compile-time**

Use this pragma to rename a field during serialization or deserialization.

**Example**:
```nim
type
  Test = object
    someVar {.rename(ser="some_var", des="some_var").}: string
```
If you want to rename the field for serialization and deserialization, just specify the new name with the first argument:
```nim
type
  Test {.des, ser.} = object
    someVar {.rename("some_var").}: string
```
]##

template renameAll*(ser: RenameKind = rkNothing, des: RenameKind = rkNothing) {.pragma.} ##[
**Only for objects, compile-time**

Use this pragma to rename all fields for the specified case.

**Example**:
```nim
type
  Test {.des, ser, renameAll(ser=rkSnakeCase, des=rkSnakeCase).} = object
    someVar: string
```
If you want to rename the field for serialization and deserialization, just specify the new name with the first argument:
```nim
type
  Test {.des, ser, renameAll(rkSnakeCase).} = object
    someVar: string
```
Look at the `available cases <utils.html#RenameKind>`_.
]##

template skipSerializeIf*(condition: typed{`proc` | `template`}) {.pragma.} ##[
**Only for fields, runtime**

Use this pragma to skip the field during serialization based on the runtime value.
You must specify a function that accepts an argument with the same type as the field, and return bool.

When used on an object, the function will only be applied to fields of the appropriate type.

**Example**:
```nim
import options

proc isZero(x: int) = x == 0

type
  Test {.des, ser.} = object
    someOption {.skipSerializeIf(isNone).}: Option[int]
    someInt {.skipSerializeIf(isZero).}: int
```
]##

template flat*() {.pragma.} ##[
**Only for fields, compile-time**

Use this pragma to inline keys from the field into the parent object.

**Example**:
```nim
type
  Pagination {.des, ser.} = object
    limit: uint64
    offset: uint64
    total: uint64
  
  Users {.des, ser.} = object
    users: seq[User]
    pagination {.flat.}: Pagination
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

The pragmas specified in the parent **object** will **NOT** be applied to the fields of the child `flat` object. 
]##

template untagged*() {.pragma.} ##[
**Only for `case` field, runtime**

By default, in object variants, the branch is selected based on the value in the raw data.
The `untagged` pragma forces deser to choose the branch itself, based on the structure of the raw data.

**Example**:
```nim
import
  deser_json

type
  MessageKind {.pure.} = enum
    Request, Response
  Test {.des, ser.} = object
    id: string
    case kind {.untagged.}: MessageKind
    of Request:
      `method`: string
      params: Params
    of Response:
      result: string

const js = """{"id": "...", "method": "GET", "params": {}}"""
var test = Test.fromJson(js)
assert test.kind == MessageKind.Request
```
]##

template skip*() {.pragma.} ##[
**Only for fields, compile-time**

Use this pragma to skip the field during serialization and deserialization.

**Example**:
```nim
type
  Test {.des, ser.} = object
    alwaysSkip {.skip.}: int
```
]##

template skipSerializing*() {.pragma.} ##[
**Only for fields, compile-time**

Use this pragma to skip the field during serialization.

**Example**:
```nim
type
  Test {.des, ser.} = object
    skipOnSerialization {.skipSerializing.}: int
```
]##

template skipDeserializing*() {.pragma.} ##[
**Only for fields, compile-time**

Use this pragma to skip the field during deserialization.

**Example**:
```nim
type
  Test {.des, ser.} = object
    skipOnDeserialization {.skipDeserializing.}: int
```
]##

template deserializeWith*(convert: typed{`proc` | `template`}) {.pragma.} ##[
**Only for fields, runtime**

Use this pragma to apply the passed function to the field during deserialization.
Can be used to convert the original type to a field type.

**Example**:
```nim
import times

type
  Message {.des, ser.} = object
    date {.deserializeWith(fromUnix).}: Time
```
]##

template serializeWith*(convert: typed{`proc` | `template`}) {.pragma.} ##[
**Only for fields, runtime**

Use this pragma to apply the passed function to the field during serialization.
Can be used to convert the field type to a original type.

**Example**:
```nim
import times

type
  Message {.des, ser.} = object
    date {.serializeWith(toUnix).}: Time
```
]##

template withDefault*(convert: typed = nil) {.pragma.} ##[
**Only for fields, runtime**

Use this pragma to set the default value if the field is not found in the raw data.

Accepts any code with type. If the pragma is empty, then `default(field.type)` is applied.

**Example**
import
  deser_json

type
  User {.des, ser.} = object
    id: int
    name {.withDefault("Unknown user").}: string
    age {.withDefault.}: int

const js = """{"id": 123}"""

var user = User.fromJson(js)

echo user.name  # Unknown user
echo user.age   # 0
]##
