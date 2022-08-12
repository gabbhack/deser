import std/[options, enumerate, macros]

from ../../des/error import
  raiseDuplicateField,
  raiseUnknownUntaggedVariant,
  raiseMissingField

from ../../des/helpers import
  implVisitor,
  IgnoredAny

import ../intermediate {.all.}

from utils {.all.} import
  getOrBreak,
  getOrDefault,
  getOrRaise,
  toByteArray

from ../sharedutils {.all.} import
  defPushPop,
  defMaybeExportedIdent,
  defWithType


{.push used.}
proc withGenerics(someType: NimNode, genericParams: NimNode): NimNode =
  expectKind someType, {nnkIdent, nnkSym}
  expectKind genericParams, nnkGenericParams

  result = nnkBracketExpr.newTree(someType)

  for param in genericParams:
    # HACK: https://github.com/nim-lang/Nim/issues/19670
    result.add ident param.strVal


proc defVisitorKeyType(visitorType, valueType: NimNode): NimNode =
  quote do:
    type
      # special type to avoid specifying the generic `Value` every time
      HackType[Value] = object
      `visitorType` = HackType[`valueType`]


proc defImplVisitor(selfType, returnType: NimNode, public: bool): NimNode =
  # implVisitor(selfType, returnType)
  let
    implVisitorSym = bindSym "implVisitor"
    public = newLit public

  quote do:
    `implVisitorSym`(`selfType`, public=`public`)


proc defKeysEnum(struct: Struct): NimNode =
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


proc defToKeyElseBranch(struct: Struct): NimNode =
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
  

proc defStrToKeyCase(struct: Struct): NimNode =
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


proc defBytesToKeyCase(struct: Struct): NimNode =
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


proc defUintToKeyCase(struct: Struct): NimNode =
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


proc defExpectingProc(selfType, body: NimNode): NimNode =
  let
    expectingIdent = ident "expecting"
    selfIdent = ident "self"

  quote do:
    proc `expectingIdent`(`selfIdent`: `selfType`): string =
      `body`


proc defVisitStringProc(selfType, returnType, body: NimNode): NimNode =
  let
    visitStringIdent = ident "visitString"
    selfIdent = ident "self"
    valueIdent = ident "value"

  quote do:
    proc `visitStringIdent`(`selfIdent`: `selfType`, `valueIdent`: string): `returnType` =
      `body`


proc defVisitBytesProc(selfType, returnType, body: NimNode): NimNode =
  let
    visitStringIdent = ident "visitBytes"
    selfIdent = ident "self"
    valueIdent = ident "value"

  quote do:
    proc `visitStringIdent`(`selfIdent`: `selfType`, `valueIdent`: openArray[byte]): `returnType` =
      `body`


proc defVisitUintProc(selfType, returnType, body: NimNode): NimNode =
  let
    visitStringIdent = ident "visitUint64"
    selfIdent = ident "self"
    valueIdent = ident "value"

  quote do:
    proc `visitStringIdent`(`selfIdent`: `selfType`, `valueIdent`: uint64): `returnType` =
      `body`


proc defKeyDeserializeBody(visitorType: NimNode): NimNode =
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


proc defDeserializeKeyProc(selfType, body: NimNode, public: bool): NimNode =
  let deserializeProcIdent = defMaybeExportedIdent(ident "deserialize", public)
  
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


proc defKeyDeserialize(visitorType: NimNode, struct: Struct, public: bool): NimNode =  
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


proc defGetOrDefault(fieldIdent: NimNode, defaultValue: NimNode): NimNode =
  newCall(bindSym "getOrDefault", fieldIdent, defaultValue)


proc defGetOrRaise(fieldIdent: NimNode, fieldName: NimNode): NimNode =
  newCall(bindSym "getOrRaise", fieldIdent, fieldName)


proc defGetOrBreak(fieldIdent: NimNode): NimNode =
  newCall(bindSym "getOrBreak", fieldIdent)


proc defGetField(field: Field, raiseOnNone: bool): NimNode =
  let defaultValue = field.getDefaultValue

  if defaultValue.isSome:
    defGetOrDefault(field.ident, defaultValue.unsafeGet)
  elif raiseOnNone:
    defGetOrRaise(field.ident, field.deserializeName.newLit)
  else:
    defGetOrBreak(field.ident)


proc addToObjConstr(objConstr, ident, value: NimNode) =
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


proc resolve(struct: Struct, fields: seq[Field], objConstr: NimNode, raiseOnNone = true): NimNode =
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


proc defInitResolver(struct: Struct): NimNode =
  let objConstr = nnkObjConstr.newTree(
    if struct.genericParams.isSome:
      withGenerics(struct.sym, struct.genericParams.unsafeGet)
    else:
      struct.sym
  )
  resolve(struct, struct.fields, objConstr)


proc defVisitMapProc(struct: Struct, visitorType, body: NimNode): NimNode =
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


proc defOptionFieldVars(struct: Struct): NimNode =
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


proc defKeyToValueCase(struct: Struct): NimNode =
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
    let genericTypeArgument =
      if field.deserializeWithType.isSome:
        let
          withType = field.deserializeWithType.unsafeGet
          originType = field.typ
        nnkBracketExpr.newTree(
          withType,
          originType
        )
      else:
        field.typ
    
    var nextValueCall =
      newCall(
        nnkBracketExpr.newTree(
          ident "nextValue",
          genericTypeArgument
        ),
        ident "map",
      )
    
    if field.deserializeWithType.isSome:
      nextValueCall = newDotExpr(nextValueCall, ident "value")

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
            nextValueCall
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


proc defForKeys(keyType, body: NimNode): NimNode =
  #[
    for key in keys[keyType](map):
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


proc defDeserializeValueProc(struct: Struct, body: NimNode, public: bool): NimNode =
  let
    deserializeProcIdent = defMaybeExportedIdent(ident "deserialize", public)
    selfType =
      if struct.genericParams.isSome:
        withGenerics(struct.sym, struct.genericParams.unsafeGet)
      else:
        struct.sym
  
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


proc defValueDeserializeBody(struct: Struct, visitorType: NimNode): NimNode =
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


proc defDeserializeWithType(struct: Struct, public: bool): NimNode =
  result = newStmtList()

  for field in struct.flattenFields:
    if field.features.deserializeWith.isSome:
      let
        typ = field.deserializeWithType.get()
        deserializeWith = field.features.deserializeWith.unsafeGet
        deserializeIdent = defMaybeExportedIdent(ident "deserialize", public)

      result.add defWithType(typ)

      result.add quote do:
        proc `deserializeIdent`[T](Self: typedesc[`typ`[T]], deserializer: var auto): Self {.inline.} =
          when compiles(`deserializeWith`[T](deserializer)):
            result = Self(value: `deserializeWith`[T](deserializer))
          else:
            result = Self(value: `deserializeWith`(deserializer))


proc defVisitorValueType(struct: Struct, visitorType, valueType: NimNode, public: bool): NimNode =
  result = newStmtList()
  var generics, valueTyp: NimNode

  if struct.genericParams.isSome:
    generics = struct.genericParams.unsafeGet
    valueTyp = withGenerics(valueType, generics)
  else:
    generics = newEmptyNode()
    valueTyp = valueType

  let hackType = genSym(nskType, "HackType")

  result.add defDeserializeWithType(struct, public)

  result.add nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      hackType,
      nnkGenericParams.newTree(
        nnkIdentDefs.newTree(
          ident "Value",
          newEmptyNode(),
          newEmptyNode()
        )
      ),
      nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        newEmptyNode()
      )
    ),
    nnkTypeDef.newTree(
      visitorType,
      generics,
      nnkBracketExpr.newTree(
        hackType,
        valueTyp
      )
    )
  )


proc defVisitSeqProc(struct: Struct, visitorType, body: NimNode): NimNode =
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
    ident "visitSeq",
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
        ident "sequence",
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


proc defFieldLets(struct: Struct): NimNode =
  # let someField = nextElement[FieldType]()
  result = newStmtList()

  for field in struct.flattenFields:
    let genericTypeArgument =
      if field.deserializeWithType.isSome:
        let
          withType = field.deserializeWithType.unsafeGet
          originType = field.typ
        nnkBracketExpr.newTree(
          withType,
          originType
        )
      else:
        field.typ
    
    var nextElementCall =
      newCall(
        nnkBracketExpr.newTree(
          ident "nextElement",
          genericTypeArgument
        ),
        ident "sequence",
      )
    
    if field.deserializeWithType.isSome:
      # nextElement[DeserializeWith]().map(proc (x: auto): auto = x.value)
      nextElementCall = newCall(
        bindSym "map",
        nextElementCall,
        nnkLambda.newTree(
          newEmptyNode(),
          newEmptyNode(),
          newEmptyNode(),
          nnkFormalParams.newTree(
            newIdentNode("auto"),
            nnkIdentDefs.newTree(
              newIdentNode("x"),
              newIdentNode("auto"),
              newEmptyNode()
            )
          ),
          nnkPragma.newTree(
            newIdentNode("inline"),
            newIdentNode("nimcall")
          ),
          newEmptyNode(),
          nnkStmtList.newTree(
            nnkDotExpr.newTree(
              newIdentNode("x"),
              newIdentNode("value")
            )
          )
        )
      )

    result.add newLetStmt(
      field.ident,
      nextElementCall
    )


proc defValueDeserialize(visitorType: NimNode, struct: Struct, public: bool): NimNode =  
  let
    visitorTypeDef = defVisitorValueType(struct, visitorType, valueType=struct.sym, public=public)
    visitorImpl = defImplVisitor(visitorType, returnType=struct.sym, public=public)
    expectingProc = defExpectingProc(visitorType, body=newLit("struct " & '`' & struct.sym.strVal & '`'))
    visitSeqProc = defVisitSeqProc(
      struct,
      visitorType,
      body=newStmtList(
        nnkMixinStmt.newTree(ident "nextElement"),
        defFieldLets(struct),
        defInitResolver(struct)
      )
    )
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
    deserializeProc = defDeserializeValueProc(
      struct,
      body=defValueDeserializeBody(struct, visitorType), 
      public=public
    )
  
  result = newStmtList(
    visitorTypeDef,
    visitorImpl,
    expectingProc,
    visitSeqProc,
    visitMapProc,
    deserializeProc
  )


proc generate(struct: Struct, public: bool): NimNode =
  let
    fieldVisitor = genSym(nskType, "FieldVisitor") 
    valueVisitor = genSym(nskType, "Visitor")

  result = defPushPop(
    newStmtList(
      defKeyDeserialize(fieldVisitor, struct, public),
      defValueDeserialize(valueVisitor, struct, public),
    )
  )
