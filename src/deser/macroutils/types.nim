discard """
  action: "compile"
"""

##[
This module contains types for the intermediate representation of objects and their fields, as well as constructors and getters.

Almost all types contain fields of type `NimNode`, so it is important to check which nodes you put.
It is recommended to use provided `init*` constructors, which do the necessary checks for you.

However, constructors from the `parsing/struct` and `parsing/field` modules are usually used.
]##

import std/[
  macros,
  options,
  sets
]

# for pattern matching and assertKind
import matching

from deser/pragmas import
  RenameCase

from anycase import
  toCase


type
  Struct* {.requiresInit.} = object
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

  Field* {.requiresInit.} = object
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

  StructFeatures* {.requiresInit.} = object
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

  FieldFeatures* {.requiresInit.} = object
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

  FieldBranchKind* = enum
    Of
    Else

  FieldBranch* {.requiresInit.} = object
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

  TypeInfo* {.requiresInit.} = object
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
func flatten(fields: seq[Field]): seq[Field]

func getRenamed(symbol: NimNode, nameIdent: NimNode): Option[string]


# # # # # # # # # # # #
# Struct
func initStruct*(
  typeSym: NimNode,
  fields: seq[Field],
  features: StructFeatures,
  genericParams: Option[NimNode],
): Struct =
  assertKind typeSym, {nnkSym}

  if Some(@genericParams) ?= genericParams:
    assertKind genericParams, {nnkGenericParams}

  Struct(
    typeSym: typeSym,
    fields: fields,
    features: features,
    genericParams: genericParams,
    flattenFields: flatten fields,
    nskTypeEnumSym: genSym(nskType, typeSym.strVal & "Fields"),
    nskEnumFieldUnknownSym: genSym(nskEnumField, "UnknownField"),
    duplicateCheck: true
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
  ## 
  ## Created automatically in the `initStruct` constructor.
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
  branches: seq[FieldBranch]
): Field =
  assertKind nameIdent, {nnkIdent}
  assertKind typeNode, {nnkSym, nnkIdent, nnkBracketExpr, nnkRefTy}

  if isCase:
    Field(
      nameIdent: nameIdent,
      typeNode: typeNode,
      features: features,
      public: public,
      isCase: true,
      branches: branches,
      nskEnumFieldSym: genSym(nskEnumField, nameIdent.strVal),
      nskTypeDeserializeWithSym: genSym(nskType, nameIdent.strVal & "DeserializeWith"),
      nskTypeSerializeWithSym: genSym(nskType, nameIdent.strVal & "SerializeWith")
    )
  else:
    Field(
      nameIdent: nameIdent,
      typeNode: typeNode,
      features: features,
      public: public,
      isCase: false,
      nskEnumFieldSym: genSym(nskEnumField, nameIdent.strVal),
      nskTypeDeserializeWithSym: genSym(nskType, nameIdent.strVal & "DeserializeWith"),
      nskTypeSerializeWithSym: genSym(nskType, nameIdent.strVal & "SerializeWith")
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

proc merge*(self: var Field, another: Field) =
  ## Add `another` field to all branches of first field.
  doAssert self.isCase
  doAssert another.isCase

  # Compiler not smart enough
  {.warning[ProveField]:off.}
  for branch in self.branches.mitems:
    var hasCase = false
    for field in branch.fields.mitems:
      if field.isCase:
        field.merge another
        hasCase = true

    if not hasCase:
      branch.fields.add another


# # # # # # # # # # # #
# StructFeatures
func initStructFeatures*(
  onUnknownKeys: Option[NimNode],
  renameAll: Option[NimNode],
  skipPrivateSerializing: bool,
  skipPrivateDeserializing: bool
): StructFeatures =
  StructFeatures(
    onUnknownKeys: onUnknownKeys,
    renameAll: renameAll,
    skipPrivateSerializing: skipPrivateSerializing,
    skipPrivateDeserializing: skipPrivateDeserializing
  )

func initEmptyStructFeatures*(): StructFeatures =
  StructFeatures(
    onUnknownKeys: none NimNode,
    renameAll: none NimNode,
    skipPrivateSerializing: false,
    skipPrivateDeserializing: false
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
  aliases: seq[NimNode]
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
    aliases: aliases
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
    aliases: @[]
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


# setters
proc `skipSerializing=`*(self: var FieldFeatures, value: bool) =
  ## `true` if `skipped` or `skipSerializing` pragmas are used.
  self.skipSerializing = value

proc `skipDeserializing=`*(self: var FieldFeatures, value: bool) =
  ## `true` if `skipped` or `skipDeserializing` pragmas are used.
  self.skipDeserializing = value

proc `renameSerialize=`*(self: var FieldFeatures, value: Option[NimNode]) =
  ## Value from `renameSerialize` pragma.
  self.renameSerialize = value

proc `renameDeserialize=`*(self: var FieldFeatures, value: Option[NimNode]) =
  ## Value from `renameDeserialize` pragma.
  self.renameDeserialize = value


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
func flatten(fields: seq[Field]): seq[Field] =
  var
    temp = newSeqOfCap[Field](fields.len)
    dedup = initHashSet[string]()

  for field in fields:
    if not field.isCase:
      temp.add field

    if field.isCase:
      if not field.features.untagged:
        temp.add initField(
          nameIdent=field.nameIdent,
          typeNode=field.typeNode,
          features=field.features,
          public=false,
          isCase=false,
          branches=newSeqOfCap[FieldBranch](0)
        )
      for branch in field.branches:
        {.warning[UnsafeSetLen]: off.}
        temp.add flatten branch.fields
        {.warning[UnsafeSetLen]: on.}

  for field in temp:
    # It will become a problem when RFC 368 is implemented
    # https://github.com/nim-lang/RFCs/issues/368
    if not dedup.containsOrIncl field.nameIdent.strVal:
      result.add field

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


# Tests
when isMainModule:
  type Test = object

  macro run =
    block:
      doAssertRaises(AssertionDefect):
        discard initStruct(
          typeSym=ident"Test",
          fields=newSeqOfCap[Field](0),
          features=initEmptyStructFeatures(),
          genericParams=none NimNode
        )

      doAssertRaises(AssertionDefect):
        discard initStruct(
          typeSym=ident"Test",
          fields=newSeqOfCap[Field](0),
          features=initEmptyStructFeatures(),
          genericParams=some newStmtList()
        )

    block:
      doAssertRaises(AssertionDefect):
        discard initField(
          nameIdent=newStmtList(),
          typeNode=bindSym"Test",
          features=initEmptyFieldFeatures(),
          public=false,
          isCase=false,
          branches=newSeqOfCap[FieldBranch](0)
        )

      doAssertRaises(AssertionDefect):
        discard initField(
          nameIdent=ident"Test",
          typeNode=newStmtList(),
          features=initEmptyFieldFeatures(),
          public=false,
          isCase=false,
          branches=newSeqOfCap[FieldBranch](0)
        )
      
      doAssertRaises(AssertionDefect):
        let field = initField(
          nameIdent=ident"Test",
          typeNode=bindSym"Test",
          features=initEmptyFieldFeatures(),
          public=false,
          isCase=false,
          branches=newSeqOfCap[FieldBranch](0)
        )
        discard branches(field)

    block:
      var
        emptyBranch = initFieldBranch(
          fields=newSeqOfCap[Field](0),
          conditionOfBranch=some nnkOfBranch.newTree()
        )

        nestedField = initField(
          nameIdent=ident"nested",
          typeNode=bindSym"Test",
          features=initEmptyFieldFeatures(),
          public=false,
          isCase=true,
          branches=(@[emptyBranch, emptyBranch])
        )

        firstFieldBranches = @[
          emptyBranch,
          initFieldBranch(
            fields=(@[nestedField]),
            conditionOfBranch=some nnkOfBranch.newTree()
          )
        ]

        firstField = initField(
          nameIdent=ident"first",
          typeNode=bindSym"Test",
          features=initEmptyFieldFeatures(),
          public=false,
          isCase=true,
          branches=firstFieldBranches
        )

        secondField = initField(
          nameIdent=ident"second",
          typeNode=bindSym"Test",
          features=initEmptyFieldFeatures(),
          public=false,
          isCase=true,
          branches=(@[emptyBranch, emptyBranch])
        )
      
      firstField.merge(secondField)

      #[
      BEFORE:

      type Some = object
        case first: Test
        of ...:
          discard
        of ...:
          case nested: Test
          of ...:
            discard
          of ...:
            discard
        
        case second: Test
        of ...:
          discard
        of ...:
          discard
      
      AFTER:
      
      type Some = object
        case first: Test
        of ...:
          case second: Test
          of ...:
            discard
          of ...:
            discard
        of ...:
          case nested: Test
          of ...:
            case second: Test
            of ...:
              discard
            of ...:
              discard
          of ...:
            case second: Test
            of ...:
              discard
            of ...:
              discard
      ]#
      doAssert firstField.branches[0].fields[0].nameIdent == ident"second"
      doAssert firstField.branches[1].fields.len == 1
      doAssert firstField.branches[1].fields[0].branches[0].fields[0].nameIdent == ident"second"
      doAssert firstField.branches[1].fields[0].branches[1].fields[0].nameIdent == ident"second"

    block:      
      doAssertRaises(AssertionDefect):
        discard initFieldBranch(
          fields=newSeqOfCap[Field](0),
          conditionOfBranch=some newStmtList()
        )
      
      doAssertRaises(AssertionDefect):
        let branch = initFieldBranch(
          fields=newSeqOfCap[Field](0),
          conditionOfBranch=none NimNode
        )

        discard conditionOfBranch(branch)

      discard initFieldBranch(
        fields=newSeqOfCap[Field](0),
        conditionOfBranch=none NimNode
      )
    
    block:
      doAssertRaises(AssertionDefect):
        discard initTypeInfo(
          typeSym=ident"Test",
          pragma=none NimNode,
          recList=none NimNode,
          genericParams=none NimNode
        )
      
      doAssertRaises(AssertionDefect):
        discard initTypeInfo(
          typeSym=bindSym"Test",
          pragma=some newEmptyNode(),
          recList=none NimNode,
          genericParams=none NimNode
        )
      
      doAssertRaises(AssertionDefect):
        discard initTypeInfo(
          typeSym=bindSym"Test",
          pragma=none NimNode,
          recList=some newEmptyNode(),
          genericParams=none NimNode
        )
      
      doAssertRaises(AssertionDefect):
        discard initTypeInfo(
          typeSym=bindSym"Test",
          pragma=none NimNode,
          recList=none NimNode,
          genericParams=some newEmptyNode()
        )

      discard initTypeInfo(
        typeSym=bindSym"Test",
        pragma=none NimNode,
        recList=none NimNode,
        genericParams=none NimNode
      )
    
    block:
      let fields = @[
        initField(
          nameIdent=ident "First",
          typeNode=bindSym "Test",
          features=initEmptyFieldFeatures(),
          public=false,
          isCase=false,
          branches=newSeqOfCap[FieldBranch](0)
        ),
        initField(
          nameIdent=ident "Second",
          typeNode=bindSym "Test",
          features=initEmptyFieldFeatures(),
          public=false,
          isCase=true,
          branches = @[
            initFieldBranch(
              fields = @[
                initField(
                  nameIdent=ident "Third",
                  typeNode=bindSym "Test",
                  features=initEmptyFieldFeatures(),
                  public=false,
                  isCase=false,
                  branches=newSeqOfCap[FieldBranch](0)
                ),
                initField(
                  nameIdent=ident "Nope",
                  typeNode=bindSym "Test",
                  features=initFieldFeatures(
                    skipSerializing=false,
                    skipDeserializing=false,
                    untagged=true,
                    renameSerialize=none NimNode,
                    renameDeserialize=none NimNode,
                    skipSerializeIf=none NimNode,
                    serializeWith=none NimNode,
                    deserializeWith=none NimNode,
                    defaultValue=none NimNode,
                    aliases = @[]
                  ),
                  public=false,
                  isCase=true,
                  branches = @[
                    initFieldBranch(
                      fields = @[
                        initField(
                          nameIdent=ident "Fourth",
                          typeNode=bindSym "Test",
                          features=initEmptyFieldFeatures(),
                          public=false,
                          isCase=false,
                          branches=newSeqOfCap[FieldBranch](0)
                        )
                      ],
                      conditionOfBranch=some nnkOfBranch.newTree()
                    )
                  ]
                )
              ],
              conditionOfBranch=some nnkOfBranch.newTree()
            ),
            initFieldBranch(
              fields = @[
                initField(
                  nameIdent=ident "Third",
                  typeNode=bindSym "Test",
                  features=initEmptyFieldFeatures(),
                  public=false,
                  isCase=false,
                  branches=newSeqOfCap[FieldBranch](0)
                ),
                initField(
                  nameIdent=ident "Nope",
                  typeNode=bindSym "Test",
                  features=initFieldFeatures(
                    skipSerializing=false,
                    skipDeserializing=false,
                    untagged=true,
                    renameSerialize=none NimNode,
                    renameDeserialize=none NimNode,
                    skipSerializeIf=none NimNode,
                    serializeWith=none NimNode,
                    deserializeWith=none NimNode,
                    defaultValue=none NimNode,
                    aliases = @[]
                  ),
                  public=false,
                  isCase=true,
                  branches = @[
                    initFieldBranch(
                      fields = @[
                        initField(
                          nameIdent=ident "Fourth",
                          typeNode=bindSym "Test",
                          features=initEmptyFieldFeatures(),
                          public=false,
                          isCase=false,
                          branches=newSeqOfCap[FieldBranch](0)
                        )
                      ],
                      conditionOfBranch=some nnkOfBranch.newTree()
                    )
                  ]
                )
              ],
              conditionOfBranch=some nnkOfBranch.newTree()
            )
          ]
        )
      ]
    
      var fieldNames = @[
        "Fourth",
        "Third",
        "Second",
        "First"
      ]

      for field in flatten fields:
        doAssert field.nameIdent.strVal == fieldNames.pop()

    block:
      let field = initField(
        nameIdent=ident "First",
        typeNode=bindSym "Test",
        features=initFieldFeatures(
          skipSerializing=false,
          skipDeserializing=false,
          untagged=false,
          renameSerialize=some newLit "Serialize",
          renameDeserialize=some newLit "Deserialize",
          skipSerializeIf=none NimNode,
          serializeWith=none NimNode,
          deserializeWith=none NimNode,
          defaultValue=none NimNode,
          aliases = @[]
        ),
        public=false,
        isCase=false,
        branches=newSeqOfCap[FieldBranch](0)
      )

      doAssert serializeName(field) == "Serialize"
      doAssert deserializeName(field) == @["Deserialize"]

    block:
      let checkTable = [
        (newLit "barFoo", "barFoo"),
        (ident "barFoo", "fooBar"),
        (bindSym "CamelCase", "fooBar"),
        (bindSym "CobolCase", "FOO-BAR"),
        (bindSym "KebabCase", "foo-bar"),
        (bindSym "PascalCase", "FooBar"),
        (bindSym "PathCase", "foo/bar"),
        (bindSym "SnakeCase", "foo_bar"),
        (bindSym "PlainCase", "foo bar"),
        (bindSym "TrainCase", "Foo-Bar"),
        (bindSym "UpperSnakeCase", "FOO_BAR"),
      ]
      for (renameValue, checkValue) in checkTable:
        let field = initField(
          nameIdent=ident "fooBar",
          typeNode=bindSym "Test",
          features=initFieldFeatures(
            skipSerializing=false,
            skipDeserializing=false,
            untagged=false,
            renameSerialize=some renameValue,
            renameDeserialize=some renameValue,
            skipSerializeIf=none NimNode,
            serializeWith=none NimNode,
            deserializeWith=none NimNode,
            defaultValue=none NimNode,
            aliases = @[]
          ),
          public=false,
          isCase=false,
          branches=newSeqOfCap[FieldBranch](0)
        )
        doAssert field.serializeName == checkValue
        doAssert field.deserializeName == @[checkValue]

      let aliasCheckTable = [
        (newLit "barFoo", @["barFoo", "fooBar"]),
        (ident "barFoo", @["fooBar"]),
        (bindSym "CamelCase", @["fooBar", "fooBar"]),
        (bindSym "CobolCase", @["FOO-BAR", "fooBar"]),
        (bindSym "KebabCase", @["foo-bar", "fooBar"]),
        (bindSym "PascalCase", @["FooBar", "fooBar"]),
        (bindSym "PathCase", @["foo/bar", "fooBar"]),
        (bindSym "SnakeCase", @["foo_bar", "fooBar"]),
        (bindSym "PlainCase", @["foo bar", "fooBar"]),
        (bindSym "TrainCase", @["Foo-Bar", "fooBar"]),
        (bindSym "UpperSnakeCase", @["FOO_BAR", "fooBar"]),
      ]

      for (renameValue, checkValue) in aliasCheckTable:
        let field = initField(
          nameIdent=ident "fooBar",
          typeNode=bindSym "Test",
          features=initFieldFeatures(
            skipSerializing=false,
            skipDeserializing=false,
            untagged=false,
            renameSerialize=none NimNode,
            renameDeserialize=none NimNode,
            skipSerializeIf=none NimNode,
            serializeWith=none NimNode,
            deserializeWith=none NimNode,
            defaultValue=none NimNode,
            aliases = @[renameValue]
          ),
          public=false,
          isCase=false,
          branches=newSeqOfCap[FieldBranch](0)
        )
        doAssert field.deserializeName == checkValue

  run()
