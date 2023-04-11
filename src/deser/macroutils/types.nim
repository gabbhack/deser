##[
This module contains types for the intermediate representation of objects and their fields, as well as constructors and getters.

Almost all types contain fields of type `NimNode`, so it is important to check which nodes you put.
It is recommended to use provided `init*` constructors, which do the necessary checks for you.

However, constructors from the `parsing/struct` and `parsing/field` modules are usually used.
]##

import std/[
  macros,
  options
]

# for pattern matching and assertKind
import matching

from deser/pragmas import
  RenameCase

from anycase import
  toCase


type
  Struct* = object
    ## Intermediate representation of type.
    ## 
    ## Usually `Struct` is initialized using the `fromTypeSym` constructor.
    ## 
    ## You can initialize `Struct` manually using the
    ## `initStruct` constructor.
    ##
    ## It is **not recommended** to initialize `Struct` another way to avoid using the wrong `NimNode`.
    typeSym: NimNode
    fields: seq[Field]
    features: StructFeatures
    genericParams: Option[NimNode]
    flattenFields: seq[Field]
    nskTypeEnumSym: NimNode
    nskEnumFieldUnknownSym: NimNode
    duplicateCheck: bool

  Field* = object
    ## Intermediate representation of type field.
    ## 
    ## Usually `Field` is initialized using
    ## `fromIdentDefs` and
    ## `fromRecCase` constructors.
    ## 
    ## The list of fields can be obtained with procedures
    ## `fieldsFromRecList` and
    ## `parseFields`.
    ## 
    ## You can initialize `Field` manually using the
    ## `initField` constructor.
    ## 
    ## It is **not recommended** to initialize `Field` another way to avoid using the wrong `NimNode`.
    nameIdent: NimNode
    typeNode: NimNode
    features: FieldFeatures
    nskEnumFieldSym: NimNode
    nskTypeDeserializeWithSym: NimNode
    nskTypeSerializeWithSym: NimNode
    public: bool
    case isCase: bool
    of true:
      branches: seq[FieldBranch]
    else:
      discard

  ParsedStruct* = object
    ## Parsed representation of type.
    ## 
    ## Usually `ParsedStruct` is initialized using the `fromTypeSym` constructor.
    ## 
    ## You can initialize `ParsedStruct` manually using the
    ## `initParsedStruct` constructor.
    ##
    ## It is **not recommended** to initialize `ParsedStruct` another way to avoid using the wrong `NimNode`.
    typeSym: NimNode
    fields: seq[ParsedField]
    features: StructFeatures
    genericParams: Option[NimNode]

  ParsedField* = object
    ## Parsed representation of type field.
    ## 
    ## Usually `ParsedField` is initialized using
    ## `fromIdentDefs` and
    ## `fromRecCase` constructors.
    ## 
    ## The list of fields can be obtained with procedures
    ## `fieldsFromRecList` and
    ## `parseFields`.
    ## 
    ## You can initialize `ParsedField` manually using the
    ## `initField` constructor.
    ## 
    ## It is **not recommended** to initialize `ParsedField` another way to avoid using the wrong `NimNode`.
    nameIdent: NimNode
    typeNode: NimNode
    features: FieldFeatures
    public: bool
    case isCase: bool
    of true:
      branches: seq[ParsedFieldBranch]
    else:
      discard

  StructFeatures* = object
    ## Features derived from pragmas.
    ## 
    ## Usually `StructFeatures` is initialized using
    ## `fromPragma` constructor.
    ## 
    ## You can initialize `StructFeatures` manually using the
    ## `initStructFeatures` constructor.
    onUnknownKeys: Option[NimNode]
    renameAll: Option[NimNode]
    skipPrivateSerializing: bool
    skipPrivateDeserializing: bool
    defaultValue: Option[NimNode]

  FieldFeatures* = object
    ## Features derived from pragmas.
    ## 
    ## Usually `FieldFeatures` is initialized using
    ## `fromPragma` constructor.
    ## 
    ## You can initialize `FieldFeatures` manually using the
    ## `initFieldFeatures` constructor.
    skipSerializing: bool
    skipDeserializing: bool
    untagged: bool

    renameSerialize: Option[NimNode]
    renameDeserialize: Option[NimNode]
    skipSerializeIf: Option[NimNode]
    serializeWith: Option[NimNode]
    deserializeWith: Option[NimNode]
    defaultValue: Option[NimNode]
    aliases: seq[NimNode]
    deserWith: Option[NimNode]

  FieldBranchKind* = enum
    Of
    Else

  FieldBranch* = object
    ## Represents branch of case field.
    ## 
    ## Usually `FieldBranch` is initialized using
    ## `fromBranch` constructor.
    ## 
    ## You can initialize `FieldBranch` manually using the
    ## `initFieldBranch` constructor.
    ## 
    ## It is **not recommended** to initialize `FieldBranch` another way to avoid using the wrong `NimNode`.
    case kind: FieldBranchKind
    of Of:
      conditionOfBranch: NimNode
    else:
      discard
    fields: seq[Field]

  ParsedFieldBranch* = object
    ## Represents branch of case field.
    ## 
    ## Usually `ParsedFieldBranch` is initialized using
    ## `fromBranch` constructor.
    ## 
    ## You can initialize `ParsedFieldBranch` manually using the
    ## `initParsedFieldBranch` constructor.
    ## 
    ## It is **not recommended** to initialize `ParsedFieldBranch` another way to avoid using the wrong `NimNode`.
    case kind: FieldBranchKind
    of Of:
      conditionOfBranch: NimNode
    else:
      discard
    fields: seq[ParsedField]

  TypeInfo* = object
    ## Not parsed representation of type.
    ## Used when we not need to parse `NimNode` to `Struct`, `Field`, `*Features`, etc.
    ## 
    ## Usually `TypeInfo` is initialized using
    ## `fromTypeSym` constructor.
    ## 
    ## You can initialize `TypeInfo` manually using the
    ## `initTypeInfo` constructor.
    ## 
    ## It is **not recommended** to initialize `TypeInfo` another way to avoid using the wrong `NimNode`.
    typeSym: NimNode
    pragma: Option[NimNode]
    recList: Option[NimNode]
    genericParams: Option[NimNode]


# # # # # # # # # # # #
# Forward declarations
func getRenamed(symbol: NimNode, nameIdent: NimNode): Option[string]


# # # # # # # # # # # #
# Struct
func initStruct*(
  typeSym: NimNode,
  fields: seq[Field],
  features: StructFeatures,
  genericParams: Option[NimNode],
  flattenFields: seq[Field],
  nskTypeEnumSym: NimNode,
  nskEnumFieldUnknownSym: NimNode,
  duplicateCheck: bool
): Struct =
  assertKind typeSym, {nnkSym}
  assertKind nskTypeEnumSym, {nnkSym}
  assertKind nskEnumFieldUnknownSym, {nnkSym}

  if Some(@genericParams) ?= genericParams:
    assertKind genericParams, {nnkGenericParams}

  Struct(
    typeSym: typeSym,
    fields: fields,
    features: features,
    genericParams: genericParams,
    flattenFields: fields,
    nskTypeEnumSym: nskTypeEnumSym,
    nskEnumFieldUnknownSym: nskEnumFieldUnknownSym,
    duplicateCheck: duplicateCheck
  )

# Struct getters
func typeSym*(self: Struct): NimNode =
  ## Type symbol.
  ##
  ## Return nnkSym NimNode.
  self.typeSym

func fields*(self: Struct): seq[Field] =
  ## Type fields.
  self.fields

func features*(self: Struct): StructFeatures =
  ## Features derived from pragmas.
  self.features

func genericParams*(self: Struct): Option[NimNode] =
  ## Generic idents from type.
  ## 
  ## Return nnkGenericParams NimNode.
  self.genericParams

func flattenFields*(self: Struct): seq[Field] =
  ## Returns all fields, including fields from all branches.
  ## Case fields are included if not marked with `untagged`.
  self.flattenFields

func nskTypeEnumSym*(self: Struct): NimNode =
  ## Special `nnkSym` NimNode for struct.
  ## Used for enum generation.
  ## 
  ## Created automatically in the `initStruct` constructor
  self.nskTypeEnumSym

func nskEnumFieldUnknownSym*(self: Struct): NimNode =
  ## Special `nnkSym` NimNode for unknown fields.
  ## Used for enum generation.
  ## 
  ## Created automatically in the `initStruct` constructor
  self.nskEnumFieldUnknownSym

func duplicateCheck*(self: Struct): bool =
  self.duplicateCheck


# setters
proc `duplicateCheck=`*(self: var Struct, value: bool) =
  self.duplicateCheck = value


# # # # # # # # # # # #
# Field
func initField*(
  nameIdent: NimNode,
  typeNode: NimNode,
  features: FieldFeatures,
  public: bool,
  isCase: bool,
  branches: seq[FieldBranch],
  nskEnumFieldSym: NimNode,
  nskTypeDeserializeWithSym: NimNode,
  nskTypeSerializeWithSym: NimNode
): Field =
  assertKind nameIdent, {nnkIdent}
  assertKind typeNode, {nnkSym, nnkIdent, nnkBracketExpr, nnkRefTy}
  assertKind nskEnumFieldSym, {nnkSym}
  assertKind nskTypeDeserializeWithSym, {nnkSym}
  assertKind nskTypeSerializeWithSym, {nnkSym}

  if isCase:
    Field(
      nameIdent: nameIdent,
      typeNode: typeNode,
      features: features,
      public: public,
      isCase: true,
      branches: branches,
      nskEnumFieldSym: nskEnumFieldSym,
      nskTypeDeserializeWithSym: nskTypeDeserializeWithSym,
      nskTypeSerializeWithSym: nskTypeSerializeWithSym
    )
  else:
    Field(
      nameIdent: nameIdent,
      typeNode: typeNode,
      features: features,
      public: public,
      isCase: false,
      nskEnumFieldSym: nskEnumFieldSym,
      nskTypeDeserializeWithSym: nskTypeDeserializeWithSym,
      nskTypeSerializeWithSym: nskTypeSerializeWithSym
    )


# Field getters
func nameIdent*(self: Field): NimNode =
  ## Field name ident.
  ## 
  ## Return nnkIdent NimNode.
  self.nameIdent

func typeNode*(self: Field): NimNode =
  ## Field type symbol.
  ## 
  ## May return nnkSym, nnkIdent or nnkBracketExpr NimNode.
  self.typeNode

func features*(self: Field): FieldFeatures =
  ## Features derived from pragmas.
  self.features

proc features*(self: var Field): var FieldFeatures =
  ## Features derived from pragmas.
  self.features

func public*(self: Field): bool =
  ## True for public fields.
  self.public

func isCase*(self: Field): bool =
  ## True for case fields.
  self.isCase

func branches*(self: Field): seq[FieldBranch] =
  ## Field branches.
  ## 
  ## Raise `AssertionDefect` for non-case fields.
  case self.isCase
  of true:
    result = self.branches
  else:
    doAssert self.isCase

proc branches*(self: var Field): var seq[FieldBranch] =
  ## Field branches.
  ## 
  ## Raise `AssertionDefect` for non-case fields.
  {.warning[ProveInit]:off.}
  case self.isCase
  of true:
    result = self.branches
  else:
    doAssert self.isCase

func nskEnumFieldSym*(self: Field): NimNode =
  ## Special `nnkSym` NimNode for field.
  ## Used for enum generation.
  ## 
  ## Created automatically in the `initField` constructor
  self.nskEnumFieldSym

func nskTypeDeserializeWithSym*(self: Field): NimNode =
  ## Special `nnkSym` NimNode for field.
  ## Used when `deserializeWith` pragma.
  ## 
  ## Created automatically in the `initField` constructor
  self.nskTypeDeserializeWithSym

func nskTypeSerializeWithSym*(self: Field): NimNode =
  ## Special `nnkSym` NimNode for field.
  ## Used when `derializeWith` pragma.
  ## 
  ## Created automatically in the `initField` constructor
  self.nskTypeSerializeWithSym

func serializeName*(self: Field): string =
  ## Returns the string from the `renameSerialize` pragma if presented, otherwise the field name.
  if Some(@rename) ?= self.features.renameSerialize:
    getRenamed(rename, self.nameIdent).get(self.nameIdent.strVal)
  else:
    self.nameIdent.strVal

func deserializeName*(self: Field): seq[string] =
  ## Returns the sequence of strings from the `renameDeserialize` pragma if presented, otherwise the field name.
  if Some(@rename) ?= self.features.renameDeserialize:
    result = @[getRenamed(rename, self.nameIdent).get(self.nameIdent.strVal)]
  elif self.features.aliases.len > 0:
    result = newSeqOfCap[string](self.features.aliases.len + 1)
    for alias in self.features.aliases:
      if Some(@renamed) ?= getRenamed(alias, self.nameIdent):
        result.add renamed
    result.add self.nameIdent.strVal
  else:
    result = @[self.nameIdent.strVal]


# # # # # # # # # # # #
# StructFeatures
func initStructFeatures*(
  onUnknownKeys: Option[NimNode],
  renameAll: Option[NimNode],
  skipPrivateSerializing: bool,
  skipPrivateDeserializing: bool,
  defaultValue: Option[NimNode]
): StructFeatures =
  StructFeatures(
    onUnknownKeys: onUnknownKeys,
    renameAll: renameAll,
    skipPrivateSerializing: skipPrivateSerializing,
    skipPrivateDeserializing: skipPrivateDeserializing,
    defaultValue: defaultValue
  )

func initEmptyStructFeatures*(): StructFeatures =
  StructFeatures(
    onUnknownKeys: none NimNode,
    renameAll: none NimNode,
    skipPrivateSerializing: false,
    skipPrivateDeserializing: false,
    defaultValue: none NimNode
  )

# StructFeatures getters
func onUnknownKeys*(self: StructFeatures): Option[NimNode] =
  ## Value from `onUnknownKeys` pragma.
  self.onUnknownKeys

func renameAll*(self: StructFeatures): Option[NimNode] =
  ## Value from `renameAll` pragma.
  self.renameAll

func skipPrivateSerializing*(self: StructFeatures): bool =
  ## True if `skipPrivateSerializing` pragma presented.
  self.skipPrivateSerializing

func skipPrivateDeserializing*(self: StructFeatures): bool =
  ## True if `skipPrivateDeserializing` pragma presented.
  self.skipPrivateDeserializing

func defaultValue*(self: StructFeatures): Option[NimNode] =
  ## Value from `defaultValue` pragma.
  self.defaultValue


# # # # # # # # # # # #
# FieldFeatures
func initFieldFeatures*(
  skipSerializing: bool,
  skipDeserializing: bool,
  untagged: bool,
  renameSerialize: Option[NimNode],
  renameDeserialize: Option[NimNode],
  skipSerializeIf: Option[NimNode],
  serializeWith: Option[NimNode],
  deserializeWith: Option[NimNode],
  defaultValue: Option[NimNode],
  aliases: seq[NimNode],
  deserWith: Option[NimNode]
): FieldFeatures =
  ##[
Throws a `ValueError` exception if both `renameDeserialize` and `aliases` are passed.
  ]##
  if renameDeserialize.isSome and aliases.len > 0:
    raise newException(ValueError, "Cannot use both `aliases` and `renameDeserialize` on the same field.")

  FieldFeatures(
    skipSerializing: skipSerializing,
    skipDeserializing: skipDeserializing,
    untagged: untagged,
    renameSerialize: renameSerialize,
    renameDeserialize: renameDeserialize,
    skipSerializeIf: skipSerializeIf,
    serializeWith: serializeWith,
    deserializeWith: deserializeWith,
    defaultValue: defaultValue,
    aliases: aliases,
    deserWith: deserWith
  )

func initEmptyFieldFeatures*(): FieldFeatures =
  FieldFeatures(
    skipSerializing: false,
    skipDeserializing: false,
    untagged: false,
    renameSerialize: none NimNode,
    renameDeserialize: none NimNode,
    skipSerializeIf: none NimNode,
    serializeWith: none NimNode,
    deserializeWith: none NimNode,
    defaultValue: none NimNode,
    aliases: @[],
    deserWith: none NimNode
  )

# FieldFeatures getters
func skipSerializing*(self: FieldFeatures): bool =
  ## `true` if `skipped` or `skipSerializing` pragmas are used.
  self.skipSerializing

func skipDeserializing*(self: FieldFeatures): bool =
  ## `true` if `skipped` or `skipDeserializing` pragmas are used.
  self.skipDeserializing

func untagged*(self: FieldFeatures): bool =
  ## `true` if `untagged` pragma used.
  self.untagged

func renameSerialize*(self: FieldFeatures): Option[NimNode] =
  ## Value from `renameSerialize` pragma.
  self.renameSerialize

func renameDeserialize*(self: FieldFeatures): Option[NimNode] =
  ## Value from `renameDeserialize` pragma.
  self.renameDeserialize

func skipSerializeIf*(self: FieldFeatures): Option[NimNode] =
  ## Value from `skipSerializeIf` pragma.
  self.skipSerializeIf

func serializeWith*(self: FieldFeatures): Option[NimNode] =
  ## Value from `serializeWith` pragma.
  self.serializeWith

func deserializeWith*(self: FieldFeatures): Option[NimNode] =
  ## Value from `deserializeWith` pragma.
  self.deserializeWith

func defaultValue*(self: FieldFeatures): Option[NimNode] =
  ## Value from `defaultValue` pragma.
  self.defaultValue

func aliases*(self: FieldFeatures): seq[NimNode] =
  ## Value from `aliases` pragma.
  self.aliases

func deserWith*(self: FieldFeatures): Option[NimNode] =
  ## Value from `deserWith` pragma.
  self.deserWith


# setters
proc `skipSerializing=`*(self: var FieldFeatures, value: bool) =
  self.skipSerializing = value

proc `skipDeserializing=`*(self: var FieldFeatures, value: bool) =
  self.skipDeserializing = value

proc `renameSerialize=`*(self: var FieldFeatures, value: Option[NimNode]) =
  self.renameSerialize = value

proc `renameDeserialize=`*(self: var FieldFeatures, value: Option[NimNode]) =
  self.renameDeserialize = value

proc `defaultValue=`*(self: var FieldFeatures, value: Option[NimNode]) =
  self.defaultValue = value


# # # # # # # # # # # #
# FieldBranch
func initFieldBranch*(
  fields: seq[Field],
  conditionOfBranch: Option[NimNode]
): FieldBranch =

  if Some(@conditionOfBranch) ?= conditionOfBranch:
    assertKind conditionOfBranch, {nnkOfBranch, nnkIdent}

    FieldBranch(
      kind: Of,
      fields: fields,
      conditionOfBranch: conditionOfBranch
    )
  else:
    FieldBranch(
      kind: Else,
      fields: fields
    )

# FieldBranch getters
func kind*(self: FieldBranch): FieldBranchKind =
  self.kind

func conditionOfBranch*(self: FieldBranch): NimNode =
  ## Condition of `Of` branch without body.
  ## 
  ## Return nnkOfBranch or nnkIdent (``) NimNode.
  ## 
  ## Raise `AssertionDefect` for non-Of branches.
  case self.kind
  of Of:
    result = self.conditionOfBranch
  else:
    doAssert self.kind == Of

func fields*(self: FieldBranch): seq[Field] =
  self.fields

proc fields*(self: var FieldBranch): var seq[Field] =
  self.fields


# # # # # # # # # # # #
# ParsedStruct
func initParsedStruct*(
  typeSym: NimNode,
  fields: seq[ParsedField],
  features: StructFeatures,
  genericParams: Option[NimNode]
): ParsedStruct =
  assertKind typeSym, {nnkSym}

  if genericParams.isSome:
    assertKind genericParams.get(), {nnkGenericParams}

  ParsedStruct(
    typeSym: typeSym,
    fields: fields,
    features: features,
    genericParams: genericParams
  )

func typeSym*(self: ParsedStruct): NimNode =
  ## Type symbol.
  ##
  ## Return nnkSym NimNode.
  self.typeSym

func fields*(self: ParsedStruct): seq[ParsedField] =
  ## Type fields.
  self.fields

func features*(self: ParsedStruct): StructFeatures =
  ## Features derived from pragmas.
  self.features

func genericParams*(self: ParsedStruct): Option[NimNode] =
  ## Generic idents from type.
  ## 
  ## Return nnkGenericParams NimNode.
  self.genericParams


# # # # # # # # # # # #
# ParsedField
func initParsedField*(
  nameIdent: NimNode,
  typeNode: NimNode,
  features: FieldFeatures,
  public: bool,
  isCase: bool,
  branches: seq[ParsedFieldBranch],
): ParsedField =
  assertKind nameIdent, {nnkIdent}
  assertKind typeNode, {nnkSym, nnkIdent, nnkBracketExpr, nnkRefTy}

  if isCase:
    ParsedField(
      nameIdent: nameIdent,
      typeNode: typeNode,
      features: features,
      public: public,
      isCase: true,
      branches: branches,
    )
  else:
    ParsedField(
      nameIdent: nameIdent,
      typeNode: typeNode,
      features: features,
      public: public,
      isCase: false,
    )

func nameIdent*(self: ParsedField): NimNode =
  ## Field name ident.
  ## 
  ## Return nnkIdent NimNode.
  self.nameIdent

func typeNode*(self: ParsedField): NimNode =
  ## Field type symbol.
  ## 
  ## May return nnkSym, nnkIdent or nnkBracketExpr NimNode.
  self.typeNode

proc features*(self: var ParsedField): var FieldFeatures =
  ## Features derived from pragmas.
  self.features

func features*(self: ParsedField): FieldFeatures =
  ## Features derived from pragmas.
  self.features

func public*(self: ParsedField): bool =
  ## True for public fields.
  self.public

func isCase*(self: ParsedField): bool =
  ## True for case fields.
  self.isCase

func branches*(self: ParsedField): seq[ParsedFieldBranch] =
  ## Field branches.
  ## 
  ## Raise `AssertionDefect` for non-case fields.
  case self.isCase
  of true:
    result = self.branches
  else:
    doAssert self.isCase

proc branches*(self: var ParsedField): var seq[ParsedFieldBranch] =
  ## Field branches.
  ## 
  ## Raise `AssertionDefect` for non-case fields.
  {.warning[ProveInit]:off.}
  case self.isCase
  of true:
    result = self.branches
  else:
    doAssert self.isCase


# # # # # # # # # # # #
# ParsedFieldBranch
func initParsedFieldBranch*(
  fields: seq[ParsedField],
  conditionOfBranch: Option[NimNode]
): ParsedFieldBranch =

  if Some(@conditionOfBranch) ?= conditionOfBranch:
    assertKind conditionOfBranch, {nnkOfBranch, nnkIdent}

    ParsedFieldBranch(
      kind: Of,
      fields: fields,
      conditionOfBranch: conditionOfBranch
    )
  else:
    ParsedFieldBranch(
      kind: Else,
      fields: fields
    )

func kind*(self: ParsedFieldBranch): FieldBranchKind =
  self.kind

func conditionOfBranch*(self: ParsedFieldBranch): NimNode =
  ## Condition of `Of` branch without body.
  ## 
  ## Return nnkOfBranch or nnkIdent (``) NimNode.
  ## 
  ## Raise `AssertionDefect` for non-Of branches.
  case self.kind
  of Of:
    result = self.conditionOfBranch
  else:
    doAssert self.kind == Of

func fields*(self: ParsedFieldBranch): seq[ParsedField] =
  self.fields

proc fields*(self: var ParsedFieldBranch): var seq[ParsedField] =
  self.fields


# # # # # # # # # # # #
# TypeInfo
func initTypeInfo*(
  typeSym: NimNode, 
  pragma: Option[NimNode], 
  recList: Option[NimNode],
  genericParams: Option[NimNode]
): TypeInfo =
  assertKind typeSym, {nnkSym}

  if pragma.isSome:
    assertKind pragma.get(), {nnkPragma}

  if recList.isSome:
    assertKind recList.get(), {nnkRecList}
  
  if genericParams.isSome:
    assertKind genericParams.get(), {nnkGenericParams}

  TypeInfo(
    typeSym: typeSym,
    pragma: pragma,
    recList: recList,
    genericParams: genericParams
  )

func typeSym*(self: TypeInfo): NimNode =
  ## Symbol that user passed to the macro.
  ## Usually used to show nice errors.
  ## 
  ## Return `nnkSym` NimNode.
  self.typeSym

func pragma*(self: TypeInfo): Option[NimNode] =
  ## Type pragma.
  ## 
  ## Return `nnkPragma` NimNode.
  self.pragma

func recList*(self: TypeInfo): Option[NimNode] =
  ## Type recList.
  ## 
  ## Return `nnkRecList`.
  self.recList

func genericParams*(self: TypeInfo): Option[NimNode] =
  ## Generic idents from type.
  ## 
  ## Return nnkGenericParams NimNode.
  self.genericParams


# # # # # # # # # # # #
# Utils
func getRenamed(symbol: NimNode, nameIdent: NimNode): Option[string] =
  if symbol == bindSym("CamelCase"):
    some nameIdent.strVal.toCase CamelCase
  elif symbol == bindSym("CobolCase"):
    some  nameIdent.strVal.toCase CobolCase
  elif symbol == bindSym("KebabCase"):
    some nameIdent.strVal.toCase KebabCase
  elif symbol == bindSym("PascalCase"):
    some nameIdent.strVal.toCase PascalCase
  elif symbol == bindSym("PathCase"):
    some nameIdent.strVal.toCase PathCase
  elif symbol == bindSym("SnakeCase"):
    some nameIdent.strVal.toCase SnakeCase
  elif symbol == bindSym("PlainCase"):
    some nameIdent.strVal.toCase PlainCase
  elif symbol == bindSym("TrainCase"):
    some nameIdent.strVal.toCase TrainCase
  elif symbol == bindSym("UpperSnakeCase"):
    some nameIdent.strVal.toCase UpperSnakeCase
  elif symbol.kind == nnkStrLit:
    some symbol.strVal
  else:
    none string
