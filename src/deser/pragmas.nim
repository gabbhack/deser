import utils

# https://github.com/nim-lang/Nim/issues/16158
template rename*(ser = "", des = "") {.pragma.}  ##[
  Use this pragma to rename a field during serialization or deserialization.
  Example:
  ```nim
  type
    Test = object
      someVar {.rename(ser="some_var", des="someVar").}: string
  ```
  If you want to rename the field for serialization and deserialization, just specify the new name with the first argument:
  ```nim
  type
    Test = object
      someVar {.rename("some_var").}: string
  ```
]##
template renameAll*(ser: RenameKind = rkNothing, des: RenameKind = rkNothing) {.pragma.}
template skipSerializeIf*(condition: typed{`proc`}) {.pragma.}
template flat*() {.pragma.}
template skip*() {.pragma.}
template skipSerializing*() {.pragma.}
template skipDeserializing*() {.pragma.}
template deserializeWith*(convert: typed{`proc`}) {.pragma.}
template serializeWith*(convert: typed{`proc`}) {.pragma.}
