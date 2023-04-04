import std/[
  macros,
  options
]

import deser/macroutils/matching

from deser/ser/helpers import
  asAddr

from deser/macroutils/types import
  Struct,
  flattenFields,
  typeSym,
  fields,
  Field,
  typeNode,
  features,
  isCase,
  branches,
  nskTypeSerializeWithSym,
  serializeName,
  nameIdent,
  # FieldFeatures
  serializeWith,
  skipSerializing,
  skipSerializeIf,
  untagged,
  deserWith,
  # FieldBranch
  kind,
  conditionOfBranch,
  FieldBranchKind

from deser/macroutils/generation/utils import
  defWithType,
  defMaybeExportedIdent,
  defPushPop


# Forward declarations
func defSerializeWith(struct: Struct, public: bool): NimNode

func defSerializeProc(struct: Struct, body: NimNode, public: bool): NimNode

func defSerializeBody(struct: Struct): NimNode

func defState(): NimNode

func defSerializeFields(fields: seq[Field]): NimNode

func defSerializeField(field: Field, checkSkipIf: bool): NimNode

func defSerializeCaseField(field: Field): NimNode

func defEndMap(): NimNode

func defSelfDotField(field: Field): NimNode

func defCheckedSerializeField(field: Field, checker, body: NimNode): NimNode

func defNilCheck(): NimNode


func defSerialize*(struct: Struct, public: bool): NimNode =
  defPushPop:
    newStmtList(
      defSerializeWith(
        struct,
        public=public
      ),
      defSerializeProc(
        struct,
        body=defSerializeBody(struct),
        public=public
      )
    )

func defSerializeWith(struct: Struct, public: bool): NimNode =
  result = newStmtList()

  for field in struct.flattenFields:
    if field.features.serializeWith.isSome or field.features.deserWith.isSome:
      let
        typ = field.nskTypeSerializeWithSym
        serializeIdent = defMaybeExportedIdent(ident "serialize", public)
        selfIdent = ident "self"
        serializerIdent = ident "serializer"
        serializeWithBody =
          if Some(@serializeWith) ?= field.features.serializeWith:
            newCall(serializeWith, newDotExpr(ident "self", ident "value"), ident "serializer")
          elif Some(@deserWith) ?= field.features.deserWith:
            newCall(ident "serialize", deserWith, newDotExpr(ident "self", ident "value"), ident "serializer")
          else:
            doAssert false
            newEmptyNode()

      result.add defWithType(typ)

      result.add quote do:
        proc `serializeIdent`[T](`selfIdent`: `typ`[T], `serializerIdent`: var auto) {.inline.} =
          `serializeWithBody`

func defSerializeProc(struct: Struct, body: NimNode, public: bool): NimNode =
  let procName = defMaybeExportedIdent(ident "serialize", public)

  nnkProcDef.newTree(
    procName,
    newEmptyNode(),
    newEmptyNode(),
    nnkFormalParams.newTree(
      newEmptyNode(),
      nnkIdentDefs.newTree(
        newIdentNode("self"),
        struct.typeSym,
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        newIdentNode("serializer"),
        nnkVarTy.newTree(
          newIdentNode("auto")
        ),
        newEmptyNode()
      )
    ),
    newEmptyNode(),
    newEmptyNode(),
    body
  )

func defSerializeBody(struct: Struct): NimNode =
  newStmtList(
    nnkMixinStmt.newTree(
      ident "serializeMap"
    ),
    nnkMixinStmt.newTree(
      ident "serializeMapEntry"
    ),
    nnkMixinStmt.newTree(
      ident "endMap"
    ),
    defNilCheck(),
    defState(),
    defSerializeFields(struct.fields),
    defEndMap()
  )

func defNilCheck(): NimNode =
  let
    selfIdent = ident "self"
    serializerIdent = ident "serializer"
    serializeNoneIdent = ident "serializeNone"

  quote do:
    when `selfIdent` is ref:
      if `selfIdent`.isNil:
        `serializeNoneIdent`(`serializerIdent`)
        return

func defState(): NimNode =
  newCall(
    bindSym "asAddr",
    ident "state",
    nnkCall.newTree(
      newIdentNode("serializeMap"),
      newIdentNode("serializer"),
      newCall(
        bindSym "none",
        ident "int"
      )
    )
  )

func defSerializeFields(fields: seq[Field]): NimNode =
  result = newStmtList()

  for field in fields:
    if not field.features.skipSerializing:
      if field.isCase:
        result.add defSerializeCaseField(field)
      else: 
        result.add defSerializeField(field, checkSkipIf=true)

func defEndMap(): NimNode =
  newCall(
    ident "endMap",
    ident "state"
  )

func defSerializeCaseField(field: Field): NimNode =
  let skipSerializeIf = field.features.skipSerializeIf
  var tempStmt = newStmtList()

  if not field.features.untagged:
    tempStmt.add defSerializeField(field, checkSkipIf=false)

  var caseStmt = nnkCaseStmt.newTree(defSelfDotField(field))
  for variant in field.branches:
    let variantBody = defSerializeFields(variant.fields)

    case variant.kind
    of Of:
      var condition = (copy variant.conditionOfBranch).add variantBody
      caseStmt.add condition
    else:
      caseStmt.add nnkElse.newTree(variantBody)
  
  tempStmt.add caseStmt

  if skipSerializeIf.isSome:
    defCheckedSerializeField(
      field,
      skipSerializeIf.unsafeGet,
      body = tempStmt
    )
  else:
    tempStmt

func defSerializeField(field: Field, checkSkipIf: bool): NimNode =
  let 
    skipSerializeIf = field.features.skipSerializeIf
    serializeWithType = field.nskTypeSerializeWithSym
    serializeFieldArgument =
      if field.features.serializeWith.isSome or field.features.deserWith.isSome:
        nnkObjConstr.newTree(
          nnkBracketExpr.newTree(
            serializeWithType,
            field.typeNode
          ),
          nnkExprColonExpr.newTree(
            newIdentNode("value"),
            defSelfDotField(field)
          )
        )
      else:
        defSelfDotField(field)

    call = newCall(
      ident "serializeMapEntry",
      ident "state",
      newLit field.serializeName,
      serializeFieldArgument
    )

  if skipSerializeIf.isSome and checkSkipIf:
    defCheckedSerializeField(
      field,
      checker=skipSerializeIf.unsafeGet,
      body=call
    )
  else:
    call

func defSelfDotField(field: Field): NimNode =
  newDotExpr(
    ident "self",
    field.nameIdent
  )

func defCheckedSerializeField(field: Field, checker, body: NimNode): NimNode =
  nnkIfStmt.newTree(
    nnkElifBranch.newTree(
      nnkPrefix.newTree(
        ident "not",
        nnkCall.newTree(
          checker,
          defSelfDotField(field)
        )
      ),
      body
    )
  )
