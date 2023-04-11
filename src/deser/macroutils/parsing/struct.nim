{.experimental: "caseStmtMacros".}

import std/[
  macros,
  options,
  strformat
]

from deser/macroutils/types as macro_types import
  TypeInfo,
  initTypeInfo,
  recList,
  pragma,

  ParsedStruct,
  initParsedStruct,
  genericParams,

  StructFeatures,
  initStructFeatures,
  initEmptyStructFeatures,

  ParsedField,
  isCase,
  branches,
  public,
  features,
  fields,
  aliases,
  renameSerialize,
  renameDeserialize,
  `skipSerializing=`,
  `skipDeserializing=`,
  `renameSerialize=`,
  `renameDeserialize=`,
  `defaultValue=`

from deser/macroutils/types import nil

from field import
  parseFields

from pragmas as parse_pragmas import
  parsePragma

from deser/pragmas import
  renameAll,
  onUnknownKeys,
  skipPrivate,
  skipPrivateSerializing,
  skipPrivateDeserializing,
  defaultValue,
  RenameCase

# for pattern matching and assertKind
import deser/macroutils/matching

# Forward declaration
func fromTypeSym*(typeInfoTy: typedesc[TypeInfo], typeSym: NimNode): TypeInfo

func fromPragma*(featuresTy: typedesc[StructFeatures], pragma: Option[NimNode]): StructFeatures

func showUnsupportedObjectError(symbol: NimNode, nodeKind: NimNodeKind) {.noreturn.}

func mergeRecList*(toNode, fromNode: NimNode): NimNode

func mergePragma(toNode, fromNode: NimNode): NimNode

# Parse
func fromTypeSym*(structTy: typedesc[ParsedStruct], typeSym: NimNode): ParsedStruct =
  ## Parse `nnkSym` node and return `Struct`.
  bind
    pragmas.onUnknownKeys,
    pragmas.skipPrivate,
    pragmas.renameAll,
    pragmas.skipPrivateSerializing,
    pragmas.skipPrivateDeserializing,
    pragmas.defaultValue

  let
    typeInfo = TypeInfo.fromTypeSym(typeSym)
    features = StructFeatures.fromPragma(typeInfo.pragma)
    fields = parseFields(typeInfo)

  initParsedStruct(
    typeSym=typeSym,
    fields=fields,
    features=features,
    genericParams=typeInfo.genericParams
  )

func fromTypeSym*(typeInfoTy: typedesc[TypeInfo], typeSym: NimNode): TypeInfo =
  ## Parse `nnkSym` node and return `TypeInfo`.
  
  assertMatch typeSym:
    (@typeSym is Sym()) |
    (BracketExpr[@typeSym is Sym(), .._])

  let declaration = typeSym.getImpl()

  if declaration.kind == nnkNilLit:
    error(
      "No type declaration. Maybe it is a built-in type. Almost all built-in types are serializable by default",
      typeSym
    )
  else:
    assertKind declaration, {nnkTypeDef}

  let implementation = declaration[2]

  if implementation.kind notin {nnkObjectTy, nnkRefTy}:
    showUnsupportedObjectError(typeSym, implementation.kind)
  
  if implementation.kind == nnkRefTy and implementation[0].kind != nnkObjectTy:
    showUnsupportedObjectError(typeSym, implementation[0].kind)

  assertMatch declaration:
    TypeDef[
      PragmaExpr[_, @pragma] | Sym(),
      (@genericParams is GenericParams()) | Empty(),
      RefTy[@objectTy is ObjectTy()] | (@objectTy is ObjectTy()),
    ]
  
  assertMatch objectTy:
    ObjectTy[
      _,
      OfInherit[@parentTypeSym] | Empty(),
      (@recList is RecList()) | Empty()
    ]
  
  if Some(@parentTypeSym) ?= parentTypeSym:
    let parentTypeInfo = TypeInfo.fromTypeSym(parentTypeSym)

    if Some(@parentRecList) ?= parentTypeInfo.recList:
      if Some(@recListValue) ?= recList:
        recList = some mergeRecList(parentRecList, recListValue)
      else:
        recList = some parentRecList
      
    if Some(@parentPragma) ?= parentTypeInfo.pragma:
      if Some(@pragmaValue) ?= pragma:
        pragma = some mergePragma(pragmaValue, parentPragma)
      else:
        pragma = some parentPragma

  initTypeInfo(
    typeSym=typeSym,
    pragma=pragma,
    recList=recList,
    genericParams=genericParams
  )

func fromPragma*(featuresTy: typedesc[StructFeatures], pragma: Option[NimNode]): StructFeatures =
  ## Parse `nnkPragma` node and return `StructFeatures`.

  if Some(@pragma) ?= pragma:
    assertKind pragma, {nnkPragma}

    let
      onUnknownKeysSym = bindSym("onUnknownKeys")
      renameAllSym = bindSym("renameAll")
      skipPrivateSym = bindSym("skipPrivate")
      skipPrivateSerializingSym = bindSym("skipPrivateSerializing")
      skipPrivateDeserializingSym = bindSym("skipPrivateDeserializing")
      defaultValueSym = bindSym("defaultValue")

    var
      onUnknownKeys = none NimNode
      renameAll = none NimNode
      skipPrivateSerializing = false
      skipPrivateDeserializing = false
      defaultValue = none NimNode

    for symbol, values in parsePragma(pragma):
      if symbol == onUnknownKeysSym:
        onUnknownKeys = some values[0]
      elif symbol == renameAllSym:
        renameAll = some values[0]
      elif symbol == skipPrivateSym:
        skipPrivateSerializing = true
        skipPrivateDeserializing = true
      elif symbol == skipPrivateSerializingSym:
        skipPrivateSerializing = true
      elif symbol == skipPrivateDeserializingSym:
        skipPrivateDeserializing = true
      elif symbol == defaultValueSym:
        if values[0].kind == nnkNilLit:
          defaultValue = some newEmptyNode()
        else:
          defaultValue = some values[0]

    initStructFeatures(
      onUnknownKeys=onUnknownKeys,
      renameAll=renameAll,
      skipPrivateSerializing=skipPrivateSerializing,
      skipPrivateDeserializing=skipPrivateDeserializing,
      defaultValue=defaultValue
    )
  else:
    initEmptyStructFeatures()

func showUnsupportedObjectError(symbol: NimNode, nodeKind: NimNodeKind) {.noreturn.} =
  case nodeKind
  of nnkSym:
    error("Aliases are not supported. Call the `make(De)Serializable` macro for the base type.", symbol)
  of nnkEnumTy:
    error("Enums are serializable by default.", symbol)
  of nnkInfix, nnkTypeClassTy:
    error("Type classes are not supported.", symbol)
  of nnkTupleConstr, nnkTupleTy:
    error("Tuples are serializable by default.", symbol)
  else:
    error(
      fmt"Node of kind `{nodeKind}` is not supported.",
      symbol
    )

func mergeRecList(toNode, fromNode: NimNode): NimNode =
  assertKind toNode, {nnkRecList}
  assertKind fromNode, {nnkRecList}

  result = copy toNode

  for field in fromNode:
    result.add field

func mergePragma(toNode, fromNode: NimNode): NimNode =
  assertKind toNode, {nnkPragma}
  assertKind fromNode, {nnkPragma}

  result = copy toNode

  for pragma in fromNode:
    result.add pragma
