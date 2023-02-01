import std/[
  macros,
  enumerate,
  options
]

import deser/macroutils/matching

from deser/macroutils/types import
  Struct,
  flattenFields,
  nskTypeEnumSym,
  nskEnumFieldUnknownSym,
  typeSym,
  # Field
  nskEnumFieldSym,
  deserializeName,
  # StructFeatures
  onUnknownKeys,
  # Field and Struct
  features

from deser/macroutils/generation/utils import
  defMaybeExportedIdent,
  defPushPop

from utils as des_utils import
  defImplVisitor,
  defExpectingProc,
  toByteArray


# Forward declarations
func defKeysEnum(struct: Struct): NimNode

func defVisitorKeyType(visitorType, valueType: NimNode): NimNode

func defVisitStringProc(selfType, returnType, body: NimNode): NimNode

func defVisitUintProc(selfType, returnType, body: NimNode): NimNode

func defVisitBytesProc(selfType, returnType, body: NimNode): NimNode

func defDeserializeKeyProc(selfType, body: NimNode, public: bool): NimNode

func defKeyDeserializeBody(visitorType: NimNode): NimNode

func defStrToKeyCase(struct: Struct): NimNode

func defBytesToKeyCase(struct: Struct): NimNode

func defUintToKeyCase(struct: Struct): NimNode

func defToKeyElseBranch(struct: Struct): NimNode


func defKeyDeserialize*(visitorType: NimNode, struct: Struct, public: bool): NimNode =  
  let
    keysEnum = defKeysEnum(struct)
    visitorTypeDef = defVisitorKeyType(
      visitorType,
      valueType=struct.nskTypeEnumSym
    )
    visitorImpl = defImplVisitor(
      visitorType,
      public=public
    )
    expectingProc = defExpectingProc(
      visitorType,
      body=newLit "field identifier"
    )
    visitStringProc = defVisitStringProc(
      visitorType,
      returnType=struct.nskTypeEnumSym,
      body=defStrToKeyCase(struct)
    )
    visitBytesProc = defVisitBytesProc(
      visitorType,
      returnType=struct.nskTypeEnumSym,
      body=defBytesToKeyCase(struct)
    )
    visitUintProc = defVisitUintProc(
      visitorType,
      returnType=struct.nskTypeEnumSym,
      body=defUintToKeyCase(struct)
    )
    deserializeProc = defDeserializeKeyProc(
      struct.nskTypeEnumSym,
      body=defKeyDeserializeBody(visitorType),
      public=public
    )

  defPushPop:
    newStmtList(
      keysEnum,
      visitorTypeDef,
      visitorImpl,
      expectingProc,
      visitStringProc,
      visitBytesProc,
      visitUintProc,
      deserializeProc
    )

func defKeysEnum(struct: Struct): NimNode =
  #[
    type Enum = enum
      FirstKey
      SecondKey
  ]#
  var enumNode = nnkEnumTy.newTree(
    newEmptyNode()
  )

  for field in struct.flattenFields:
    enumNode.add field.nskEnumFieldSym

  enumNode.add struct.nskEnumFieldUnknownSym

  nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      struct.nskTypeEnumSym,
      newEmptyNode(),
      enumNode
    )
  )

func defVisitorKeyType(visitorType, valueType: NimNode): NimNode =
  quote do:
    type
      # special type to avoid specifying the generic `Value` every time
      HackType[Value] = object
      `visitorType` = HackType[`valueType`]

func defVisitStringProc(selfType, returnType, body: NimNode): NimNode =
  let
    visitStringIdent = ident "visitString"
    selfIdent = ident "self"
    valueIdent = ident "value"

  quote do:
    proc `visitStringIdent`(`selfIdent`: `selfType`, `valueIdent`: string): `returnType` =
      `body`

func defVisitBytesProc(selfType, returnType, body: NimNode): NimNode =
  let
    visitStringIdent = ident "visitBytes"
    selfIdent = ident "self"
    valueIdent = ident "value"

  quote do:
    proc `visitStringIdent`(`selfIdent`: `selfType`, `valueIdent`: openArray[byte]): `returnType` =
      `body`

func defVisitUintProc(selfType, returnType, body: NimNode): NimNode =
  let
    visitStringIdent = ident "visitUint64"
    selfIdent = ident "self"
    valueIdent = ident "value"

  quote do:
    proc `visitStringIdent`(`selfIdent`: `selfType`, `valueIdent`: uint64): `returnType` =
      `body`

func defDeserializeKeyProc(selfType, body: NimNode, public: bool): NimNode =
  let
    deserializeProcIdent = defMaybeExportedIdent(ident "deserialize", public)
    selfIdent = ident "selfType"
    deserializerIdent = ident "deserializer"

  quote do:
    proc `deserializeProcIdent`(`selfIdent`: typedesc[`selfType`], `deserializerIdent`: var auto): `selfIdent` =
      `body`

func defKeyDeserializeBody(visitorType: NimNode): NimNode =
  let
    deserializeIdentifierIdent = ident "deserializeIdentifier"
    deserializerIdent = ident "deserializer"

  newStmtList(
    nnkMixinStmt.newTree(deserializeIdentifierIdent),
    newCall(deserializeIdentifierIdent, deserializerIdent, newCall(visitorType))
  )

func defStrToKeyCase(struct: Struct): NimNode =
  #[
    case value
    of "key":
      Enum.Key
    else:
      
  ]#
  result = nnkCaseStmt.newTree(
    newIdentNode("value")
  )

  for field in struct.flattenFields:
    for name in field.deserializeName:
      result.add nnkOfBranch.newTree(
        newLit name,
        newStmtList(
          newDotExpr(
            struct.nskTypeEnumSym,
            field.nskEnumFieldSym
          )
        )
      )

  result.add defToKeyElseBranch(struct)

func defBytesToKeyCase(struct: Struct): NimNode =
  if struct.flattenFields.len == 0:
    # hardcode for empty objects
    # cause if statement with only `else` branch is nonsense
    result = newDotExpr(struct.nskTypeEnumSym, struct.nskEnumFieldUnknownSym)
  else:
    result = nnkIfStmt.newTree()

    for field in struct.flattenFields:
      for name in field.deserializeName:
        result.add nnkElifBranch.newTree(
          nnkInfix.newTree(
            ident "==",
            ident "value",
            newCall(bindSym "toByteArray", newLit name)
          ),
          newStmtList(
            newDotExpr(
              struct.nskTypeEnumSym,
              field.nskEnumFieldSym
            )
          )
        )

    result.add defToKeyElseBranch(struct)

func defUintToKeyCase(struct: Struct): NimNode =
  # HACK: https://github.com/nim-lang/Nim/issues/20031
  if struct.flattenFields.len == 0:
    # hardcode for empty objects
    # cause if statement with only `else` branch is nonsense
    result = newDotExpr(struct.nskTypeEnumSym, struct.nskEnumFieldUnknownSym)
  else:
    result = nnkIfStmt.newTree()
    
    for (num, field) in enumerate(struct.flattenFields):
      result.add nnkElifBranch.newTree(
        nnkInfix.newTree(
          ident "==",
          ident "value",
          newLit num
        ),
        newStmtList(
          newDotExpr(
            struct.nskTypeEnumSym,
            field.nskEnumFieldSym
          )
        )
      )

    result.add defToKeyElseBranch(struct)

func defToKeyElseBranch(struct: Struct): NimNode =
  let
    callOnUnknownKeys = block:
      if Some(@onUnknownKeys) ?= struct.features.onUnknownKeys:
        newCall(
          onUnknownKeys,
          toStrLit struct.typeSym,
          ident "value"
        )
      else:
        newEmptyNode()

  nnkElse.newTree(
    newStmtList(
      callOnUnknownKeys,
      newDotExpr(
          struct.nskTypeEnumSym,
          struct.nskEnumFieldUnknownSym
      )
    )
  )
