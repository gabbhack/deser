{.experimental: "strictFuncs".}
import std/[macros]

from std/options import Option, unsafeGet, isSome, some, none

import ../macroutils {.all.}

from error import raiseInvalidType, raiseDuplicateField
from impls import implVisitor


type
  EnumField = object
    enumFieldIdent: NimNode
    structFieldIdent: NimNode
  
  EnumInfo = object
    name: NimNode
    fields: seq[EnumField]
    unknownField: NimNode


func genEnumFields(fields: seq[Field]): seq[EnumField] {.noinit.} =
  result = newSeqOfCap[EnumField](fields.len)
  for field in fields:
    result.add EnumField(
      enumFieldIdent: genSym(nskEnumField, field.name.strVal),
      structFieldIdent: field.name
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
          enumType,
          field.enumFieldIdent
        )
      )
    )
  
  caseStmt.add nnkElse.newTree(
    newStmtList(
      newDotExpr(
          enumType,
          enumInfo.unknownField
        )
    )
  )

  let
    expectingIdent = newExportedIdent("expecting")
    expectingProc = quote do:
      proc `expectingIdent`(self: `visitorType`): string {.inline.} =
        "field identifier"
  
  let
    visitStrIdent = newExportedIdent("visitStr")
    visitStrProc = quote do:
      proc `visitStrIdent`(self: `visitorType`, value: string): `enumType` {.inline.} =
        `caseStmt`

  let
    deserializeIdent = newExportedIdent("deserialize")
    deserializeProc = quote do:
      proc `deserializeIdent`(self: typedesc[`enumType`], deserializer: auto): `enumType` {.inline.} =
        deserializer.deserializeIdentifier(`visitorType`())
  
  result = newStmtList(
    visitorTypeDef,
    visitorImpl,
    expectingProc,
    visitStrProc,
    deserializeProc
  )


func genValueDeserializeNode(visitorType: NimNode, struct: Struct, enumInfo: EnumInfo): NimNode =
  let
    visitorTypeDef = nnkTypeSection.newTree(
      nnkTypeDef.newTree(
        visitorType,
        newEmptyNode(),
        newEmptyNode()
      )
    )

    optionSym = bindSym "Option"
    isSomeSym = bindSym "isSome"
    getSym = bindSym "unsafeGet"
    noneSym = bindSym "none"
    someSym = bindSym "some"
    raiseDuplicateFieldSym = bindSym "raiseDuplicateField"
    mapIdent = ident "map"
    keyIdent = ident "key"
    nextValueIdent = ident "nextValue"

  var visitMapProcBody = newStmtList(
    nnkMixinStmt.newTree(ident "keys"),
    nnkMixinStmt.newTree(ident "nextValue"),
  )

  # set fields vars
  for field in struct.fields:
    let
      fieldName = field.name
      fieldTyp = field.typ

    visitMapProcBody.add quote do:
      var `fieldName` = `noneSym`(`fieldTyp`)
  
  var caseStmt = nnkCaseStmt.newTree(
    keyIdent
  )

  for field in enumInfo.fields:
    let
      structField = field.structFieldIdent
      structFieldStr = structField.toStrLit

    caseStmt.add nnkOfBranch.newTree(
      newDotExpr(
          enumInfo.name,
          field.enumFieldIdent
      ),
      quote do:
        if `isSomeSym`(`structField`):
          raise `raiseDuplicateFieldSym`(`structFieldStr`)
        `structField` = `someSym` `nextValueIdent`(`mapIdent`)
    )
  
  caseStmt.add nnkElse.newTree(
    newStmtList(
      nnkDiscardStmt.newTree(newEmptyNode())
    )
  )

  visitMapProcBody.add quote do:
    for `keyIdent` in `mapIdent`.keys:
      `caseStmt`
  

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


type
  TestKind = enum
    First,
    Second
  
  Fields = enum
    FirstField,
    SecondField,
    ThirdField
  
  Test = object
    case kind: TestKind
    of First:
      a: int
    else:
      b: int


proc visitMap[M](self: Test, map: var M): Test =
  var kind = none TestKind
  var a = none int
  var b = none int

  for key in map.keys:
    case key
    of FirstField:
      kind = some map.nextValue(TestKind)
    of SecondField:
      a = some map.nextValue()
