import utils

# ISSUE: https://github.com/nim-lang/Nim/issues/16158
template rename*(ser = "", des = "") {.pragma.} ##[
  **Only for fields**

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
    Test = object
      someVar {.rename("some_var").}: string
  ```
]##

template renameAll*(ser: RenameKind = rkNothing, des: RenameKind = rkNothing) {.pragma.} ##[
  **Only for objects**

  Use this pragma to rename all fields for the specified case.

  **Example**:
  ```nim
  type
    Test {.renameAll(ser=rkSnakeCase, des=rkSnakeCase).} = object
      someVar: string
  ```
  If you want to rename the field for serialization and deserialization, just specify the new name with the first argument:
  ```nim
  type
    Test {.renameAll(rkSnakeCase).} = object
      someVar: string
  ```
]##

template skipSerializeIf*(condition: typed{`proc`}) {.pragma.} ##[
  **For fields and objects**

  Use this pragma to skip the field during serialization based on the runtime value.
  You must specify a function that accepts an argument with the same type as the field, and return bool.

  When used on an object, the function will only be applied to fields of the appropriate type.

  **Example**:
  ```nim
  import options

  proc isZero(x: int) = x == 0

  type
    Test {.skipSerializeIf(isNone).} = object
      someOption: Option[int]
      someInt {.skipSerializeIf(isZero).}: int
  ```
]##

template flat*() {.pragma.} ##[
  **Only for fields**

  Use this pragma to inlines keys from the field into the parent object.

  **Example**:
  ```nim
  type
    Pagination = object
      limit: uint64
      offset: uint64
      total: uint64
    
    Users = object
      users: seq[User]
      pagination {.flat.}: Pagination
  ```
]##

template skip*() {.pragma.} ##[
  **Only for fields**

  Use this pragma to skip the field during serialization and deserialization.

  **Example**:
  ```nim
    type
      Test = object
        alwaysSkip {.skip.}: int
  ```
]##

template skipSerializing*() {.pragma.} ##[
  **Only for fields**

  Use this pragma to skip the field during serialization.

  **Example**:
  ```nim
    type
      Test = object
        skipOnSerialization {.skipSerializing.}: int
  ```
]##

template skipDeserializing*() {.pragma.} ##[
  **Only for fields**

  Use this pragma to skip the field during deserialization.

  **Example**:
  ```nim
    type
      Test = object
        skipOnDeserialization {.skipSerializing.}: int
  ```
]##

template deserializeWith*(convert: typed{`proc`}) {.pragma.} ##[
  **For fields and objects**

  Use this pragma to apply the passed function to the field during deserialization.
  Can be used to convert the original type to a field type.

  When used on an object, the function will only be applied to fields of the appropriate type.

  **Example**:
  ```nim
  import times

  type
    Message = object
      date {.deserializeWith(fromUnix).}: Time
  ```
]##

template serializeWith*(convert: typed{`proc`}) {.pragma.} ##[
  **For fields and objects**

  Use this pragma to apply the passed function to the field during serialization.
  Can be used to convert the field type to a original type.

  When used on an object, the function will only be applied to fields of the appropriate type.

  **Example**:
  ```nim
  import times

  type
    Message = object
      date {.serializeWith(toUnix).}: Time
  ```
]##
