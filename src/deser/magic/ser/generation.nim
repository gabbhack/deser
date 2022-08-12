import std/[
  macros,
  options
]

import ../intermediate {.all.}

from ../sharedutils {.all.} import
  defPushPop,
  defMaybeExportedIdent,
  defWithType

from utils {.all.} import
  asAddr


{.push used.}
proc defSerializeFields(fields: seq[Field]): NimNode

proc defSelfDotField(field: Field): NimNode =
  result = newDotExpr(
    ident "self",
    field.ident
  )


proc defSerializeWith(struct: Struct, public: bool): NimNode =
  result = newStmtList()

  for field in struct.flattenFields:
    if field.features.serializeWith.isSome:
      let
        typ = field.serializeWithType.get()
        serializeWith = field.features.serializeWith.unsafeGet
        serializeIdent = defMaybeExportedIdent(ident "serialize", public)

      result.add defWithType(typ)

      result.add quote do:
        proc `serializeIdent`[T](self: `typ`[T], serializer: var auto) {.inline.} =
          `serializeWith`(self.value, serializer)


proc defSerializeProc(struct: Struct, body: NimNode, public: bool): NimNode =
  let procName = defMaybeExportedIdent(ident "serialize", public)

  result = nnkProcDef.newTree(
    procName,
    newEmptyNode(),
    newEmptyNode(),
    nnkFormalParams.newTree(
      newEmptyNode(),
      nnkIdentDefs.newTree(
        newIdentNode("self"),
        struct.sym,
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


proc defState(): NimNode =
  result = newCall(
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


proc defCheckedSerializeField(field: Field, checker, body: NimNode): NimNode =
  result = nnkIfStmt.newTree(
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


proc defSerializeField(field: Field, checkSkipIf: bool): NimNode =
  let 
    skipSerializeIf = field.getSkipSerializeIf()
    serializeWithType = field.serializeWithType
    serializeFieldArgument =
      if serializeWithType.isSome:
        nnkObjConstr.newTree(
          nnkBracketExpr.newTree(
            serializeWithType.unsafeGet,
            field.typ
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
    result = defCheckedSerializeField(
      field,
      checker=skipSerializeIf.unsafeGet,
      body=call
    )
  else:
    result = call


proc defSerializeCaseField(field: Field): NimNode =
  let skipSerializeIf = field.getSkipSerializeIf()
  var tempStmt = newStmtList()

  if not field.isUntagged:
    tempStmt.add defSerializeField(field, checkSkipIf=false)

  var caseStmt = nnkCaseStmt.newTree(defSelfDotField(field))
  for variant in field.branches:
    let variantBody = defSerializeFields(variant.fields)

    case variant.kind
    of Of:
      var condition = (copy variant.condition).add variantBody
      caseStmt.add condition
    else:
      caseStmt.add nnkElse.newTree(variantBody)
  
  tempStmt.add caseStmt

  if skipSerializeIf.isSome:
    result = defCheckedSerializeField(
      field,
      skipSerializeIf.unsafeGet,
      body = tempStmt
    )
  else:
    result = tempStmt


proc defSerializeFields(fields: seq[Field]): NimNode =
  result = newStmtList()

  for field in fields:
    if not field.isSkipSerializing:
      if field.isCase:
        result.add defSerializeCaseField(field)
      else: 
        result.add defSerializeField(field, checkSkipIf=true)


proc defEndMap(): NimNode =
  result = newCall(
    ident "endMap",
    ident "state"
  )

proc defSerializeBody(struct: Struct): NimNode =
  result = newStmtList(
    nnkMixinStmt.newTree(
      ident "serializeMap"
    ),
    nnkMixinStmt.newTree(
      ident "serializeMapEntry"
    ),
    nnkMixinStmt.newTree(
      ident "endMap"
    ),
    defState(),
    defSerializeFields(struct.fields),
    defEndMap()
  )


proc defSerialize(struct: var Struct, public: bool): NimNode =
  result = newStmtList(
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


proc generate(struct: var Struct, public: bool): NimNode =
  result = defPushPop(
    defSerialize(struct, public)
  )
{.pop.}
