{.experimental: "strictFuncs".}
import std/[options, macros, enumerate]

import parse {.all.}

from ../des/error import raiseInvalidType, raiseDuplicateField, raiseUnknownUntaggedVariant
from ../des/provided import implVisitor


{.push used.}
template getOrRaise[T](field: Option[T], name: static[string]): T =
  if field.isNone:
    when T is Option:
      default(T)
    else:
      raiseMissingField(name)
  else:
    field.unsafeGet


template getOrBreak[T](field: Option[T]): T =
  if field.isNone:
    when T is Option:
      default(T)
    else:
      break
  else:
    field.unsafeGet


template getOrDefault[T](field: Option[T], defaultValue: T): T =
  if field.isNone:
    defaultValue
  else:
    field.unsafeGet


macro toByteArray(str: static[string]): array =
  result = nnkBracket.newTree()
  
  for s in str:
    result.add s.byte.newLit


func defVisitorType(visitorType, valueType: NimNode): NimNode =
  quote do:
    type
      # special type to avoid specifying the generic `Value` every time
      HackType[Value] = object
      `visitorType` = HackType[`valueType`]


func defImplVisitor(selfType, returnType: NimNode): NimNode =
  # implVisitor(selfType, returnType)
  let implVisitorSym = bindSym "implVisitor"

  quote do:
    `implVisitorSym`(`selfType`, `returnType`)


func defKeysEnum(keyStruct: KeyStruct): NimNode =
  #[
    type Enum = enum
      FirstKey
      SecondKey
  ]#
  var enumNode = nnkEnumTy.newTree(
    newEmptyNode()
  )

  for field in keyStruct.fields:
    enumNode.add field.enumSym
  
  enumNode.add keyStruct.unknownKeyEnumSym

  nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      keyStruct.enumSym,
      newEmptyNode(),
      enumNode
    )
  )


func defToKeyElseBranch(keyStruct: KeyStruct): NimNode =
  let onUnknownKeys = keyStruct.getOnUnknownKeysValue

  nnkElse.newTree(
    newStmtList(
      (
        if onUnknownKeys.isSome:
          newCall(onUnknownKeys.unsafeGet, keyStruct.structSym.toStrLit, ident "value")
        else:
          newEmptyNode()
      ),
      newDotExpr(
          keyStruct.enumSym,
          keyStruct.unknownKeyEnumSym
      )
    )
  ) 

func defStrToKeyCase(keyStruct: KeyStruct): NimNode =
  #[
    case value
    of "key":
      Enum.Key
  ]#
  result = nnkCaseStmt.newTree(
    newIdentNode("value")
  )

  for field in keyStruct.fields:
    result.add nnkOfBranch.newTree(
      field.deserializeName.newLit,
      newStmtList(
        newDotExpr(
          keyStruct.enumSym,
          field.enumSym
        )
      )
    )
  

  result.add defToKeyElseBranch(keyStruct)


func defBytesToKeyCase(keyStruct: KeyStruct): NimNode =
  result = nnkIfStmt.newTree()

  let toByteArraySym = bindSym "toByteArray"

  for field in keyStruct.fields:
    result.add nnkElifBranch.newTree(
      nnkInfix.newTree(
        ident "==",
        ident "value",
        newCall(toByteArraySym, field.deserializeName.newLit)
      ),
      newStmtList(
        newDotExpr(
          keyStruct.enumSym,
          field.enumSym
        )
      )
    )
  
  result.add defToKeyElseBranch(keyStruct)


func defUintToKeyCase(keyStruct: KeyStruct): NimNode =
  result = nnkIfStmt.newTree()

  for num, field in enumerate(keyStruct.fields):
    result.add nnkElifBranch.newTree(
      nnkInfix.newTree(
        ident "==",
        ident "value",
        newLit num
      ),
      newStmtList(
        newDotExpr(
          keyStruct.enumSym,
          field.enumSym
        )
      )
    )

  result.add defToKeyElseBranch(keyStruct)


func defExpectingProc(selfType, body: NimNode): NimNode =
  let
    expectingIdent = ident "expecting"
    selfIdent = ident "self"

  quote do:
    proc `expectingIdent`(`selfIdent`: `selfType`): string =
      `body`


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


func defKeyDeserializeBody(visitorType: NimNode): NimNode =
  let deserializeIdentifierIdent = ident "deserializeIdentifier"

  newStmtList(
    nnkMixinStmt.newTree(
      deserializeIdentifierIdent
    ),
    newCall(
      deserializeIdentifierIdent,
      ident "deserializer",
      visitorType
    )
  )


func defDeserializeProc(selfType, body: NimNode, public: bool): NimNode =
  let
    deserializeIdent = ident "deserialize"
    deserializeProcIdent = block:
      if public:
        nnkPostfix.newTree(ident "*", deserializeIdent)
      else:
        deserializeIdent
    selfIdent = ident "self"
    deserializerIdent = ident "deserializer"
  
  quote do:
    proc `deserializeProcIdent`(`selfIdent`: typedesc[`selfType`], `deserializerIdent`: var auto): `selfType` =
      `body`


func defKeyDeserialize(visitorType: NimNode, keyStruct: KeyStruct, public: bool): NimNode =  
  let
    keysEnum = defKeysEnum(keyStruct)
    visitorTypeDef = defVisitorType(visitorType, valueType=keyStruct.enumSym)
    visitorImpl = defImplVisitor(visitorType, returnType=keyStruct.enumSym)
    expectingProc = defExpectingProc(visitorType, body=newLit("field identifier"))
    visitStringProc = defVisitStringProc(visitorType, returnType=keyStruct.enumSym, body=defStrToKeyCase(keyStruct))
    visitBytesProc = defVisitBytesProc(visitorType, returnType=keyStruct.enumSym, body=defBytesToKeyCase(keyStruct))
    visitUintProc = defVisitUintProc(visitorType, returnType=keyStruct.enumSym, body=defUintToKeyCase(keyStruct))
    deserializeProc = defDeserializeProc(keyStruct.enumSym, body=defKeyDeserializeBody(visitorType), public)
  
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


func defGetField(field: Field, raiseOnNone: bool): NimNode =
  let
    getOrBreakSym = bindSym "getOrBreak"
    getOrRaiseSym = bindSym "getOrRaise"
    getOrDefaultSym = bindSym "getOrDefault"

    defaultValue = field.getDefaultValue

  if defaultValue.isSome:
    newCall(newDotExpr(field.ident, getOrDefaultSym), defaultValue.unsafeGet)
  elif raiseOnNone:
    newCall(newDotExpr(field.ident, getOrRaiseSym), field.deserializeName.newLit)
  else:
    newDotExpr(field.ident, getOrBreakSym)


func addToObjConstr(objConstr, ident, value: NimNode) =
  # (ident: value)
  objConstr.add newColonExpr(ident, value)


template resolveUntagged {.dirty.} =
  var body = newStmtList()

  for variant in field.branches:
    case variant.kind
    of Of:
      # every variant has diferent `kind field` value
      # so we need diferent object constructors
      var objConstr = copy objConstr
      #[
        case kind: bool
        of --> true <-- variant.condition[0]
      ]#
      addToObjConstr(objConstr, field.ident, variant.condition[0])
      # on untagged case we need to try all variants
      # so, we recursively call the resolver for each variant.
      # if an error occurs during deserialization, for example, there is no required field
      # we should exit (break) the block and try to deserialize another variant, and not throw an exception
      let variantBody = resolve(struct, variant.fields, objConstr, raiseOnNone=false)
      body.add newBlockStmt(variantBody)
    of Else:
      # since the resolver takes the value from the `Of` condition
      # we cannot guess the value in the `Else` branch
      error("untagged cases cannot have `else` branch", field.ident)

  # exception is raised only for the top level case field
  if raiseOnNone:
    body.add quote do:
      `raiseUnknownUntaggedVariantSym`(`structNameLit`, `fieldNameLit`)
  result = body


template resolveTagged {.dirty.} =
  # need to generate temp let
  # to prove that case field value is correct
  let
    tempKindLetSym = genSym(nskLet, field.deserializeName)
    # get case field value from data
    tempKindLet = newLetStmt(tempKindLetSym, defGetField(field, raiseOnNone))

  addToObjConstr(objConstr, field.ident, tempKindLetSym)
  var caseStmt = nnkCaseStmt.newTree(tempKindLetSym)

  for variant in field.branches:
    case variant.kind
    of Of:
      #[
      type Foo = object
        case kind: bool
        of true:
          ...
        else:
          ...
      
      |
      |
      |
      V

      of true  <--- condition   
      ]#
      var condition = copy variant.condition
      let variantBody = resolve(struct, variant.fields, objConstr, raiseOnNone)
      condition.add variantBody
      caseStmt.add condition
    of Else:
      let variantBody = resolve(struct, variant.fields, objConstr, raiseOnNone)
      caseStmt.add nnkElse.newTree(variantBody)
  
  result = newStmtList(
    tempKindLet,
    caseStmt
  )


func resolve(struct: Struct, fields: seq[Field], objConstr: NimNode, raiseOnNone = true): NimNode =
  let
    raiseUnknownUntaggedVariantSym = bindSym "raiseUnknownUntaggedVariant"
    structNameLit = struct.sym.toStrLit

  var 
    objConstr = copy objConstr
    caseField = none Field
  
  for field in fields:
    if not field.isSkipDeserializing:
      if field.isCase:
        if caseField.isSome:
          # hard to implement, nobody really use
          error("Object cannot contain more than one case expression at the same level", field.ident)
        caseField = some field
      else:
        addToObjConstr(objConstr, field.ident, defGetField(field, raiseOnNone))
  
  if caseField.isNone:
    # there is no case field, so just return statement
    result = nnkReturnStmt.newTree(objConstr)
  else:
    let
      field = caseField.unsafeGet
      fieldNameLit = field.deserializeName

    if field.isUntagged:
      resolveUntagged
    else:
      resolveTagged


func defInitResolver(struct: Struct): NimNode =
  resolve(struct, struct.fields, nnkObjConstr.newTree(struct.sym))


func defVisitMapProc(visitorType, returnType, body: NimNode): NimNode =
  let
    visitMapIdent = ident "visitMap"
    selfIdent = ident "self"
    mapIdent = ident "map"

  quote do:
    proc `visitMapIdent`(`selfIdent`: `visitorType`, `mapIdent`: var auto): `returnType` =
      `body`


func defOptionFieldVars(keyStruct: KeyStruct): NimNode =
  # var fieldName = none(FieldType)
  result = newStmtList()

  for field in keyStruct.fields:
    result.add newVarStmt(
      field.varIdent,
      newCall(
        bindSym("none"), field.varType
      )
    )


func defKeyToValueCase(keyStruct: KeyStruct): NimNode =
  #[
    case key
    of FirstField:
      firstField = some map.nextValue(FirstFieldType)
    ...
    else:
      discard
  ]#
  result = nnkCaseStmt.newTree(
    ident "key"
  )

  for field in keyStruct.fields:
    result.add nnkOfBranch.newTree(
      newDotExpr(keyStruct.enumSym, field.enumSym),
      newStmtList(
        nnkIfStmt.newTree(
          nnkElifBranch.newTree(
            newCall(bindSym("isSome"), field.varIdent),
            newStmtList(
              newCall(bindSym("raiseDuplicateField"), field.deserializeName.newLit)
            )
          )
        ),
        newAssignment(
          field.varIdent,
          newCall(
            bindSym("some"),
            newCall(
              ident "nextValue",
              ident "map",
              field.varType
            ),
          )
        )
      )
    )
  
  result.add nnkElse.newTree(
    newStmtList(
      nnkDiscardStmt.newTree(newEmptyNode())
    )
  )


func defForKeys(keyType, body: NimNode): NimNode =
  #[
    for key in map.keys(keyType):
      body
  ]#
  nnkForStmt.newTree(
    ident "key",
    newCall(
      newDotExpr(
        ident "map",
        ident "keys"
      ),
      keyType
    ),
    body
  )


func defValueDeserializeBody(visitorType: NimNode): NimNode =
  nnkStmtList.newTree(
    nnkMixinStmt.newTree(
      newIdentNode("deserializeMap")
    ),
    nnkCall.newTree(
      newIdentNode("deserializeMap"),
      newIdentNode("deserializer"),
      nnkCall.newTree(
        visitorType
      )
    )
  )


func defValueDeserialize(visitorType: NimNode, struct: Struct, keyStruct: KeyStruct, public: bool): NimNode =  
  let
    visitorTypeDef = defVisitorType(visitorType, valueType=struct.sym)
    visitorImpl = defImplVisitor(visitorType, returnType=struct.sym)
    expectingProc = defExpectingProc(visitorType, body=newLit("struct " & '`' & struct.sym.strVal & '`'))
    visitMapProc = defVisitMapProc(
      visitorType,
      returnType=struct.sym,
      body=newStmtList(
        nnkMixinStmt.newTree(ident "keys"),
        nnkMixinStmt.newTree(ident "nextValue"),
        defOptionFieldVars(keyStruct),
        defForKeys(keyStruct.enumSym, defKeyToValueCase(keyStruct)),
        defInitResolver(struct)
      )
    )
    deserializeProc = defDeserializeProc(struct.sym, body=defValueDeserializeBody(visitorType), public)
  
  result = newStmtList(
    visitorTypeDef,
    visitorImpl,
    expectingProc,
    visitMapProc,
    deserializeProc
  )


func defPushPop(stmtList: NimNode): NimNode =
  newStmtList(
    nnkPragma.newTree(
      ident "push",
      ident "used",
      ident "inline",
      ident "noInit"
    ),
    stmtList,
    nnkPragma.newTree(
      ident "pop"
    )
  )

func generate(struct: Struct, public: bool): NimNode =
  let
    keyStruct = KeyStruct(
      structSym: struct.sym,
      enumSym: genSym(nskType, struct.sym.strVal),
      fields: struct.fields.asKeys,
      unknownKeyEnumSym: genSym(nskEnumField, "Unknown"),
      features: struct.features
    )
    fieldVisitor = genSym(nskType, "FieldVisitor") 
    valueVisitor = genSym(nskType, "Visitor")

  result = defPushPop(
    newStmtList(
      defKeyDeserialize(fieldVisitor, keyStruct, public),
      defValueDeserialize(valueVisitor, struct, keyStruct, public),
    )
  )
{.pop.}
