{.experimental: "strictFuncs".}
import std/[macros]

from std/options import Option, unsafeGet, isSome, some, none

import ../macroutils {.all.}

from error import raiseInvalidType, raiseDuplicateField, raiseUnknownUntaggedVariant
from impls import implVisitor, getOrBreak, getOrRaise


type
  EnumField = object
    enumFieldIdent: NimNode
    structFieldIdent: NimNode
    structFieldTyp: NimNode
  
  EnumInfo = object
    name: NimNode
    fields: seq[EnumField]
    unknownField: NimNode


func genEnumFields(fields: seq[Field]): seq[EnumField] =
  result = newSeqOfCap[EnumField](fields.len)
  for field in fields:
    result.add EnumField(
      enumFieldIdent: genSym(nskEnumField, field.name.strVal),
      structFieldIdent: field.name,
      structFieldTyp: field.typ
    )

    if field.isCase:
      for branch in field.branches:
        result.add genEnumFields(branch.fields)


func genEnumNode(enumInfo: EnumInfo): NimNode =
  var enumNode = nnkEnumTy.newTree(
    newEmptyNode()
  )

  for field in enumInfo.fields:
    enumNode.add field.enumFieldIdent
  
  enumNode.add enumInfo.unknownField

  nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      enumInfo.name,
      newEmptyNode(),
      enumNode
    )
  )


func genFieldDeserializeNode(visitorType: NimNode, enumInfo: EnumInfo): NimNode =
  let
    selfIdent = ident "self"
    enumType = enumInfo.name
    visitorTypeDef = quote do:
      type
        HackType[Value] = object
        `visitorType` = HackType[`enumType`]
    
    implVisitorSym = bindSym "implVisitor"
    visitorImpl = quote do:
      `implVisitorSym`(`visitorType`, `enumType`)

  var caseStmt = nnkCaseStmt.newTree(
    newIdentNode("value")
  )

  for field in enumInfo.fields:
    caseStmt.add nnkOfBranch.newTree(
      field.structFieldIdent.toStrLit,
      newStmtList(
        newDotExpr(
          enumInfo.name,
          field.enumFieldIdent
        )
      )
    )
  
  caseStmt.add nnkElse.newTree(
    newStmtList(
      newDotExpr(
          enumInfo.name,
          enumInfo.unknownField
      )
    )
  )

  let
    expectingIdent = ident "expecting"
    expectingProc = quote do:
      proc `expectingIdent`(`selfIdent`: `visitorType`): string =
        "field identifier"
  
  let
    visitStrIdent = ident "visitString"
    valueIdent = ident "value"
    visitStrProc = quote do:
      proc `visitStrIdent`(`selfIdent`: `visitorType`, `valueIdent`: string): `enumType` {.inline.} =
        `caseStmt`

  let
    deserializeIdent = ident("deserialize")
    deserializerIdent = ident "deserializer"
    deserializeProc = quote do:
      proc `deserializeIdent`(`selfIdent`: typedesc[`enumType`], `deserializerIdent`: auto): `enumType` {.inline.} =
        deserializer.deserializeIdentifier(`visitorType`())
  
  result = newStmtList(
    visitorTypeDef,
    visitorImpl,
    expectingProc,
    visitStrProc,
    deserializeProc
  )


func resolveInit(struct: Struct, fields: seq[Field], objConstr: NimNode = nil, raiseOnNone = true): NimNode =
  let
    getOrBreakSym = bindSym "getOrBreak"
    getOrRaiseSym = bindSym "getOrRaise"
    someSym = bindSym "some"
    raiseUnknownUntaggedVariantSym = bindSym "raiseUnknownUntaggedVariant"
    structNameLit = struct.sym.toStrLit

  var objConstr = block:
    if objConstr.isNil:
      nnkObjConstr.newTree(
        struct.sym
      )
    else:
      copy objConstr

  var caseField = none Field

  for field in fields:
    if field.isCase:
      if caseField.isSome:
        error("Object cannot contain more than one case expression at the same level", field.name)
      caseField = some field
    else:
      objConstr.add:
        nnkExprColonExpr.newTree(
          field.name,
          nnkDotExpr.newTree(
            field.name,
            if raiseOnNone: getOrRaiseSym else: getOrBreakSym
          )
        )

  if caseField.isSome:
    let caseField = caseField.unsafeGet
    let caseFieldNameLit = caseField.name.toStrLit
    if caseField.features.untagged:
      var blockBody = newStmtList()
      for branch in caseField.branches:
        if branch.kind == Else:
          error("untagged cases cannot have `else` branch", casefield.name)
        else:
          var objConstr = copy objConstr
          objConstr.add:
            nnkExprColonExpr.newTree(
              caseField.name,
              branch.condition[0]
            )
          let body = resolveInit(struct, branch.fields, objConstr, false)
          blockBody.add quote do:
            block:
              `body`
      if raiseOnNone:
        blockBody.add quote do:
          `raiseUnknownUntaggedVariantSym`(`structNameLit`, `caseFieldNameLit`)
      result = blockBody
    else:
      objConstr.add:
        nnkExprColonExpr.newTree(
          caseField.name,
          nnkDotExpr.newTree(
            caseField.name,
            if raiseOnNone: getOrRaiseSym else: getOrBreakSym
          )
        )
      var caseStmt = nnkCaseStmt.newTree(nnkDotExpr.newTree(
            caseField.name,
            if raiseOnNone: getOrRaiseSym else: getOrBreakSym
          ))
      for branch in caseField.branches:
        if branch.kind == Of:
          var condition = copy branch.condition
          let body = resolveInit(struct, branch.fields, objConstr, raiseOnNone)
          condition.add body
          caseStmt.add condition
        else:
          caseStmt.add:
            nnkElse.newTree(
              nnkStmtList.newTree(
                resolveInit(struct, branch.fields, objConstr, raiseOnNone)
              )
            )
      result = caseStmt
  else:
    result = nnkReturnStmt.newTree(objConstr)

func genValueDeserializeNode(visitorType: NimNode, struct: Struct, enumInfo: EnumInfo): NimNode =
  let
    optionSym = bindSym "Option"
    isSomeSym = bindSym "isSome"
    getSym = bindSym "unsafeGet"
    noneSym = bindSym "none"
    someSym = bindSym "some"
    raiseDuplicateFieldSym = bindSym "raiseDuplicateField"
    implVisitorSym = bindSym "implVisitor"
    mapIdent = ident "map"
    keyIdent = ident "key"
    nextValueIdent = ident "nextValue"
    selfIdent = ident "self"

  let
    structName = struct.sym
    structNameLit = structName.toStrLit
    visitorTypeDef = quote do:
      type
        HackType[Value] = object
        `visitorType` = HackType[`structName`]
    
    visitorImpl = quote do:
      `implVisitorSym`(`visitorType`, `structName`)

  let
    expectingIdent = ident("expecting")
    expectingProc = quote do:
      proc `expectingIdent`(`selfIdent`: `visitorType`): string {.inline.} =
        "struct " & `structNameLit`

  var visitMapProcBody = newStmtList(
    nnkMixinStmt.newTree(ident "keys"),
    nnkMixinStmt.newTree(ident "nextValue"),
  )

  # set fields vars
  for field in enumInfo.fields:
    let
      fieldName = field.structFieldIdent
      fieldTyp = field.structFieldTyp

    visitMapProcBody.add quote do:
      var `fieldName` = `noneSym`(`fieldTyp`)
  
  var caseStmt = nnkCaseStmt.newTree(
    keyIdent
  )

  for field in enumInfo.fields:
    let
      structField = field.structFieldIdent
      structFieldStr = structField.toStrLit
      structFieldTyp = field.structFieldTyp

    caseStmt.add nnkOfBranch.newTree(
      newDotExpr(
          enumInfo.name,
          field.enumFieldIdent
      ),
      quote do:
        if `isSomeSym`(`structField`):
          raise `raiseDuplicateFieldSym`(`structFieldStr`)
        `structField` = `someSym` `nextValueIdent`(`mapIdent`, `structFieldTyp`)
    )
  
  caseStmt.add nnkElse.newTree(
    newStmtList(
      nnkDiscardStmt.newTree(newEmptyNode())
    )
  )

  let enumName = enumInfo.name
  visitMapProcBody.add quote do:
    for `keyIdent` in `mapIdent`.keys(`enumName`):
      `caseStmt`
  
  visitMapProcBody.add resolveInit(struct, struct.fields)
  
  let
    visitMapIdent = ident "visitMap"
    visitMapProc = quote do:
      proc `visitMapIdent`(`selfIdent`: `visitorType`, `mapIdent`: var auto): `structName` =
        `visitMapProcBody`
  
  result = newStmtList(
    visitorTypeDef,
    visitorImpl,
    expectingProc,
    visitMapProc
  )
  

proc generate(struct: Struct): NimNode =
  let
    enumInfo = EnumInfo(
      name: genSym(nskType, struct.sym.strVal),
      fields: genEnumFields(struct.fields),
      unknownField: genSym(nskEnumField, "Unknown")
    )
    fieldVisitorName = genSym(nskType, "FieldVisitor") 
    valueVisitorName = genSym(nskType, "Visitor")

  result = newStmtList(
    genEnumNode(enumInfo),
    genFieldDeserializeNode(fieldVisitorName, enumInfo),
    genValueDeserializeNode(valueVisitorName, struct, enumInfo)
  )


macro makeDeserializable*(typ: typed{`type`}) =
  let struct = explore(typ)
  result = generate(struct)
