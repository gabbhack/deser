{.experimental: "strictFuncs".}
import std/[options, enumerate, macros]

from ../../des/error import
  raiseDuplicateField,
  raiseUnknownUntaggedVariant,
  raiseMissingField

from ../../des/helpers import
  implVisitor,
  Visitor,
  IgnoredAny

import ../intermediate {.all.}

from utils {.all.} import
  getOrBreak,
  getOrDefault,
  getOrRaise,
  toByteArray


type
  DeserStruct = object of Struct
    flattenFields*: seq[Field]


{.push used.}
func withGenerics(someType: NimNode, genericParams: NimNode): NimNode =
  expectKind someType, {nnkIdent, nnkSym}
  expectKind genericParams, nnkGenericParams

  result = nnkBracketExpr.newTree(someType)

  for param in genericParams:
    # HACK: https://github.com/nim-lang/Nim/issues/19670
    result.add ident param.strVal


func flatten(fields: seq[Field]): seq[Field] =
  result = newSeqOfCap[Field](fields.len)

  for field in fields:
    if not field.isSkipDeserializing:
      if not field.isUntagged:
        result.add field
      if field.isCase:
        for branch in field.branches:
          result.add branch.fields.flatten


func defVisitorKeyType(visitorType, valueType: NimNode): NimNode =
  let visitorSym = bindSym "Visitor"

  quote do:
    type
      # special type to avoid specifying the generic `Value` every time
      `visitorType` = `visitorSym`[`valueType`]


func defImplVisitor(selfType, returnType: NimNode, public: bool): NimNode =
  # implVisitor(selfType, returnType)
  let
    implVisitorSym = bindSym "implVisitor"
    public = newLit public

  quote do:
    `implVisitorSym`(`selfType`, public=`public`)


func defKeysEnum(struct: DeserStruct): NimNode =
  #[
    type Enum = enum
      FirstKey
      SecondKey
  ]#
  var enumNode = nnkEnumTy.newTree(
    newEmptyNode()
  )

  for field in struct.flattenFields:
    enumNode.add field.enumFieldSym

  enumNode.add struct.enumUnknownFieldSym

  nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      struct.enumSym,
      newEmptyNode(),
      enumNode
    )
  )


func defToKeyElseBranch(struct: Struct): NimNode =
  let onUnknownKeys = struct.getOnUnknownKeysValue

  nnkElse.newTree(
    newStmtList(
      (
        if onUnknownKeys.isSome:
          newCall(
            onUnknownKeys.unsafeGet,
            struct.sym.toStrLit,
            ident "value"
          )
        else:
          newEmptyNode()
      ),
      newDotExpr(
          struct.enumSym,
          struct.enumUnknownFieldSym
      )
    )
  ) 
  

func defStrToKeyCase(struct: DeserStruct): NimNode =
  #[
    case value
    of "key":
      Enum.Key
  ]#
  result = nnkCaseStmt.newTree(
    newIdentNode("value")
  )

  for field in struct.flattenFields:
    result.add nnkOfBranch.newTree(
      field.deserializeName.newLit,
      newStmtList(
        newDotExpr(
          struct.enumSym,
          field.enumFieldSym
        )
      )
    )
  
  result.add defToKeyElseBranch(struct)


func defBytesToKeyCase(struct: DeserStruct): NimNode =
  if struct.flattenFields.len == 0:
    # hardcode for empty objects
    # cause if statement with only `else` branch is nonsense
    result = newDotExpr(struct.enumSym,struct.enumUnknownFieldSym)
  else:
    result = nnkIfStmt.newTree()

    for field in struct.flattenFields:
      result.add nnkElifBranch.newTree(
        nnkInfix.newTree(
          ident "==",
          ident "value",
          newCall(bindSym "toByteArray", field.deserializeName.newLit)
        ),
        newStmtList(
          newDotExpr(
            struct.enumSym,
            field.enumFieldSym
          )
        )
      )

    result.add defToKeyElseBranch(struct)


func defUintToKeyCase(struct: DeserStruct): NimNode =
  # HACK: https://github.com/nim-lang/Nim/issues/20031
  if struct.flattenFields.len == 0:
    # hardcode for empty objects
    # cause if statement with only `else` branch is nonsense
    result = newDotExpr(struct.enumSym,struct.enumUnknownFieldSym)
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
            struct.enumSym,
            field.enumFieldSym
          )
        )
      )

    result.add defToKeyElseBranch(struct)


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
      newCall(visitorType)
    )
  )


func defDeserializeKeyProc(selfType, body: NimNode, public: bool): NimNode =
  let
    deserializeIdent = ident "deserialize"
    deserializeProcIdent = (
      if public:
        nnkPostfix.newTree(ident "*", deserializeIdent)
      else:
        deserializeIdent
    )
  
  result = nnkProcDef.newTree(
    deserializeProcIdent,
    newEmptyNode(),
    newEmptyNode(),
    nnkFormalParams.newTree(
      ident "Self",
      nnkIdentDefs.newTree(
        ident "Self",
        nnkBracketExpr.newTree(
          ident "typedesc",
          selfType
        ),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident "deserializer",
        nnkVarTy.newTree(
          newIdentNode("auto")
        ),
        newEmptyNode()
      )
    ),
    newEmptyNode(),
    newEmptyNode(),
    nnkStmtList.newTree(
      body
    )
  )


func defKeyDeserialize(visitorType: NimNode, struct: DeserStruct, public: bool): NimNode =  
  let
    keysEnum = defKeysEnum(struct)
    visitorTypeDef = defVisitorKeyType(visitorType, valueType=struct.enumSym)
    visitorImpl = defImplVisitor(visitorType, returnType=struct.enumSym, public=public)
    expectingProc = defExpectingProc(visitorType, body=newLit("field identifier"))
    visitStringProc = defVisitStringProc(visitorType, returnType=struct.enumSym, body=defStrToKeyCase(struct))
    visitBytesProc = defVisitBytesProc(visitorType, returnType=struct.enumSym, body=defBytesToKeyCase(struct))
    visitUintProc = defVisitUintProc(visitorType, returnType=struct.enumSym, body=defUintToKeyCase(struct))
    deserializeProc = defDeserializeKeyProc(struct.enumSym, body=defKeyDeserializeBody(visitorType), public)
  
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


func defGetOrDefault(fieldIdent: NimNode, defaultValue: NimNode): NimNode =
  newCall(bindSym "getOrDefault", fieldIdent, defaultValue)


func defGetOrRaise(fieldIdent: NimNode, fieldName: NimNode): NimNode =
  newCall(bindSym "getOrRaise", fieldIdent, fieldName)


func defGetOrBreak(fieldIdent: NimNode): NimNode =
  newCall(bindSym "getOrBreak", fieldIdent)


func defGetField(field: Field, raiseOnNone: bool): NimNode =
  let defaultValue = field.getDefaultValue

  if defaultValue.isSome:
    defGetOrDefault(field.ident, defaultValue.unsafeGet)
  elif raiseOnNone:
    defGetOrRaise(field.ident, field.deserializeName.newLit)
  else:
    defGetOrBreak(field.ident)


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
  # HACK: need to generate temp let
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
          # hard(?) to implement, nobody really use
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
  let objConstr = nnkObjConstr.newTree(
    if struct.genericParams.isSome:
      withGenerics(struct.sym, struct.genericParams.unsafeGet)
    else:
      struct.sym
  )
  resolve(struct, struct.fields, objConstr)


func defVisitMapProc(struct: DeserStruct, visitorType, body: NimNode): NimNode =
  var generics, returnType, visitorTyp: NimNode

  if struct.genericParams.isSome:
    generics = struct.genericParams.unsafeGet
    returnType = withGenerics(struct.sym, struct.genericParams.unsafeGet)
    visitorTyp = withGenerics(visitorType, struct.genericParams.unsafeGet)
  else:
    generics = newEmptyNode()
    returnType = struct.sym
    visitorTyp = visitorType

  result = nnkProcDef.newTree(
    ident "visitMap",
    newEmptyNode(),
    generics,
    nnkFormalParams.newTree(
      returnType,
      nnkIdentDefs.newTree(
        ident "self",
        visitorTyp,
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident "map",
        nnkVarTy.newTree(
          newIdentNode("auto")
        ),
        newEmptyNode()
      )
    ),
    newEmptyNode(),
    newEmptyNode(),
    nnkStmtList.newTree(
      body
    )
  )


func defOptionFieldVars(struct: DeserStruct): NimNode =
  # var fieldName = none(FieldType)
  result = newStmtList()

  for field in struct.flattenFields:
    result.add newVarStmt(
      field.ident,
      newCall(
        nnkBracketExpr.newTree(
          bindSym("none"), field.typ
        )
      )
    )


func defKeyToValueCase(struct: DeserStruct): NimNode =
  #[
    case key
    of FirstField:
      firstField = some nextValue[FirstFieldType](map)
    ...
    else:
      nextValue[IgnoredAny](map)
  ]#
  result = nnkCaseStmt.newTree(
    ident "key"
  )

  for field in struct.flattenFields:
    result.add nnkOfBranch.newTree(
      newDotExpr(struct.enumSym, field.enumFieldSym),
      newStmtList(
        nnkIfStmt.newTree(
          nnkElifBranch.newTree(
            newCall(bindSym("isSome"), field.ident),
            newStmtList(
              newCall(bindSym("raiseDuplicateField"), field.deserializeName.newLit)
            )
          )
        ),
        newAssignment(
          field.ident,
          newCall(
            bindSym("some"),
            newCall(
              nnkBracketExpr.newTree(
                ident "nextValue",
                field.typ
              ),
              ident "map",
            ),
          )
        )
      )
    )
  
  result.add nnkElse.newTree(
    nnkDiscardStmt.newTree(
      newCall(
        nnkBracketExpr.newTree(
          ident "nextValue",
          bindSym "IgnoredAny"
        ),
        ident "map"
      )
    )
  )


func defForKeys(keyType, body: NimNode): NimNode =
  #[
    for key in map.keys[keyType]():
      body
  ]#
  nnkForStmt.newTree(
    ident "key",
    newCall(
      nnkBracketExpr.newTree(
        ident "keys",
        keyType
      ),
      ident "map"
    ),
    body
  )


func defDeserializeValueProc(struct: DeserStruct, body: NimNode, public: bool): NimNode =
  let
    deserializeIdent = ident "deserialize"
    deserializeProcIdent = (
      if public:
        nnkPostfix.newTree(ident "*", deserializeIdent)
      else:
        deserializeIdent
    )
    selfType = (
      if struct.genericParams.isSome:
        withGenerics(struct.sym, struct.genericParams.unsafeGet)
      else:
        struct.sym
    )
  
  result = nnkProcDef.newTree(
    deserializeProcIdent,
    newEmptyNode(),
    struct.genericParams.get(newEmptyNode()),
    nnkFormalParams.newTree(
      ident "Self",
      nnkIdentDefs.newTree(
        ident "Self",
        nnkBracketExpr.newTree(
          ident "typedesc",
          selfType
        ),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident "deserializer",
        nnkVarTy.newTree(
          newIdentNode("auto")
        ),
        newEmptyNode()
      )
    ),
    newEmptyNode(),
    newEmptyNode(),
    nnkStmtList.newTree(
      body
    )
  )


func defValueDeserializeBody(struct: DeserStruct, visitorType: NimNode): NimNode =
  let visitorType = (
    if struct.genericParams.isSome:
      withGenerics(visitorType, struct.genericParams.unsafeGet)
    else:
      visitorType
  )

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


func defVisitorValueType(struct: DeserStruct, visitorType, valueType: NimNode): NimNode =
  var generics, valueTyp: NimNode

  if struct.genericParams.isSome:
    generics = struct.genericParams.unsafeGet
    valueTyp = withGenerics(valueType, generics)
  else:
    generics = newEmptyNode()
    valueTyp = valueType

  result = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      visitorType,
      generics,
      nnkBracketExpr.newTree(
        bindSym "Visitor",
        valueTyp
      )
    )
  )


func defValueDeserialize(visitorType: NimNode, struct: DeserStruct, public: bool): NimNode =  
  let
    visitorTypeDef = defVisitorValueType(struct, visitorType, valueType=struct.sym)
    visitorImpl = defImplVisitor(visitorType, returnType=struct.sym, public=public)
    expectingProc = defExpectingProc(visitorType, body=newLit("struct " & '`' & struct.sym.strVal & '`'))
    visitMapProc = defVisitMapProc(
      struct,
      visitorType,
      body=newStmtList(
        nnkMixinStmt.newTree(ident "keys"),
        nnkMixinStmt.newTree(ident "nextValue"),
        defOptionFieldVars(struct),
        defForKeys(struct.enumSym, defKeyToValueCase(struct)),
        defInitResolver(struct)
      )
    )
    deserializeProc = defDeserializeValueProc(struct, body=defValueDeserializeBody(struct, visitorType), public)
  
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


func generate(struct: DeserStruct, public: bool): NimNode =
  let
    fieldVisitor = genSym(nskType, "FieldVisitor") 
    valueVisitor = genSym(nskType, "Visitor")

  result = defPushPop(
    newStmtList(
      defKeyDeserialize(fieldVisitor, struct, public),
      defValueDeserialize(valueVisitor, struct, public),
    )
  )