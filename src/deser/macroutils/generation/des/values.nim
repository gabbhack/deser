import std/[
  macros,
  options
]

import deser/macroutils/matching

from deser/des/errors import
  raiseDuplicateField,
  raiseUnknownUntaggedVariant,
  raiseMissingField

from deser/des/helpers import
  IgnoredAny

from deser/macroutils/types import
  Struct,
  flattenFields,
  nskTypeEnumSym,
  nskEnumFieldUnknownSym,
  typeSym,
  genericParams,
  fields,
  Field,
  isCase,
  branches,
  nskEnumFieldSym,
  deserializeName,
  nameIdent,
  nskTypeDeserializeWithSym,
  duplicateCheck,
  # FieldFeatures
  deserializeWith,
  skipDeserializing,
  defaultValue,
  untagged,
  deserWith,
  # Field and Struct
  features,
  # FieldBranch
  kind,
  conditionOfBranch,
  FieldBranchKind

from utils as des_utils import
  defImplVisitor,
  defExpectingProc,
  defFieldNamesLit,
  getOrDefault,
  getOrDefaultValue,
  getOrRaise,
  getOrBreak

from deser/macroutils/generation/utils import
  defWithType,
  defMaybeExportedIdent,
  defPushPop

# Forward declarations
func defVisitorValueType(struct: Struct, visitorType, valueType: NimNode, public: bool): NimNode

func defDeserializeWithType(struct: Struct, public: bool): NimNode

func defWithGenerics(someType: NimNode, genericParams: NimNode): NimNode

func defVisitSeqProc(struct: Struct, visitorType, body: NimNode): NimNode

func defFieldLets(struct: Struct): NimNode

func defFieldType(struct: Struct, field: Field): NimNode

func defInitResolver(struct: Struct): NimNode

func defStructType(struct: Struct): NimNode

func resolve(struct: Struct, fields: seq[Field], objConstr: NimNode, raiseOnNone = true): NimNode

func addToObjConstr(objConstr, ident, value: NimNode)

func defGetField(field: Field, raiseOnNone: bool): NimNode

func defGetOrDefault(fieldIdent: NimNode): NimNode

func defGetOrDefaultValue(fieldIdent: NimNode, defaultValue: NimNode): NimNode

func defGetOrRaise(fieldIdent: NimNode, fieldName: NimNode): NimNode

func defGetOrBreak(fieldIdent: NimNode): NimNode

func defVisitMapProc(struct: Struct, visitorType, body: NimNode): NimNode

func defOptionFieldVars(struct: Struct): NimNode

func defForKeys(keyType, body: NimNode): NimNode

func defKeyToValueCase(struct: Struct): NimNode

func defDeserializeValueProc(struct: Struct, body: NimNode, public: bool): NimNode

func defValueDeserializeBody(struct: Struct, visitorType: NimNode): NimNode

func defValueDeserialize*(visitorType: NimNode, struct: Struct, public: bool): NimNode =  
  let
    visitorTypeDef = defVisitorValueType(
      struct,
      visitorType,
      valueType=struct.typeSym,
      public=public
    )
    visitorImpl = defImplVisitor(
      visitorType,
      public=public
    )
    expectingProc = defExpectingProc(
      visitorType,
      body=newLit "struct " & '`' & struct.typeSym.strVal & '`'
    )
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
        defForKeys(struct.nskTypeEnumSym, defKeyToValueCase(struct)),
        defInitResolver(struct)
      )
    )
    deserializeProc = defDeserializeValueProc(
      struct,
      body=defValueDeserializeBody(struct, visitorType), 
      public=public
    )

  defPushPop:
    newStmtList(
      visitorTypeDef,
      visitorImpl,
      expectingProc,
      visitSeqProc,
      visitMapProc,
      deserializeProc
    )

func defVisitorValueType(struct: Struct, visitorType, valueType: NimNode, public: bool): NimNode =
  result = newStmtList()
  var generics, valueTyp: NimNode

  if Some(@genericParams) ?= struct.genericParams:
    valueTyp = defWithGenerics(valueType, genericParams)
    generics = genericParams
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

func defDeserializeWithType(struct: Struct, public: bool): NimNode =
  result = newStmtList()

  for field in struct.flattenFields:
    if field.features.deserializeWith.isSome or field.features.deserWith.isSome:
      let
        typ = field.nskTypeDeserializeWithSym
        deserializeIdent = defMaybeExportedIdent(ident "deserialize", public)
        deserializerIdent = ident "deserializer"
        value =
          if Some(@deserializeWith) ?= field.features.deserializeWith:
            newCall(deserializeWith, deserializerIdent)
          elif Some(@deserWith) ?= field.features.deserWith:
            newCall(ident "deserialize", deserWith, deserializerIdent)
          else:
            doAssert false
            newEmptyNode()
        genericValue = block:
          let tmp = copy value
          tmp[0] = nnkBracketExpr.newTree(tmp[0], ident "T")
          tmp

      result.add defWithType(typ)

      result.add quote do:
        proc `deserializeIdent`[T](selfTy: typedesc[`typ`[T]], `deserializerIdent`: var auto): selfTy {.inline.} =
          mixin deserialize

          when compiles(`genericValue`):
            selfTy(value: `genericValue`)
          else:
            selfTy(value: `value`)

func defWithGenerics(someType: NimNode, genericParams: NimNode): NimNode =
  assertKind someType, {nnkIdent, nnkSym}
  assertKind genericParams, {nnkGenericParams}

  result = nnkBracketExpr.newTree(someType)

  for param in genericParams:
    # HACK: https://github.com/nim-lang/Nim/issues/19670
    result.add ident param.strVal

func defVisitSeqProc(struct: Struct, visitorType, body: NimNode): NimNode =
  var generics, returnType, visitorTyp: NimNode

  if Some(@genericParams) ?= struct.genericParams:
    returnType = defWithGenerics(struct.typeSym, genericParams)
    visitorTyp = defWithGenerics(visitorType, genericParams)
    generics = genericParams
  else:
    generics = newEmptyNode()
    returnType = struct.typeSym
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

func defFieldLets(struct: Struct): NimNode =
  # let someField = nextElement[FieldType](sequence)
  result = newStmtList()

  for field in struct.flattenFields:
    let 
      genericTypeArgument =
        if field.features.deserializeWith.isSome or field.features.deserWith.isSome:
          let
            withType = field.nskTypeDeserializeWithSym
            originType = defFieldType(struct, field)

          nnkBracketExpr.newTree(
            withType,
            originType
          )
        else:
          defFieldType(struct, field)

      sequenceIdent = ident "sequence"
    
    
    var nextElementCall = quote do:
      nextElement[`genericTypeArgument`](`sequenceIdent`)

    if field.features.deserializeWith.isSome or field.features.deserWith.isSome:
      # nextElement returns Option[T]
      nextElementCall = quote do:
        block:
          if isSome(`nextElementCall`):
            some(unsafeGet(`nextElementCall`).value)
          else:
            none(`genericTypeArgument`.T)

    result.add newLetStmt(
      field.nameIdent,
      nextElementCall
    )

func defFieldType(struct: Struct, field: Field): NimNode =
  newCall(
    ident "typeof",
    newDotExpr(
      ident "result",
      field.nameIdent
    )
  )

func defInitResolver(struct: Struct): NimNode =
  let objConstr = nnkObjConstr.newTree(defStructType(struct))

  resolve(struct, struct.fields, objConstr)

func defStructType(struct: Struct): NimNode =
  if Some(@genericParams) ?= struct.genericParams:
    defWithGenerics(struct.typeSym, genericParams)
  else:
    struct.typeSym

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
      addToObjConstr(objConstr, field.nameIdent, variant.conditionOfBranch[0])
      # on untagged case we need to try all variants
      # so, we recursively call the resolver for each variant.
      # if an error occurs during deserialization, for example, there is no required field
      # we should exit (break) the block and try to deserialize another variant, and not throw an exception
      let variantBody = resolve(struct, variant.fields, objConstr, raiseOnNone=false)
      body.add newBlockStmt(variantBody)
    of Else:
      # since the resolver takes the value from the `Of` condition
      # we cannot guess the value in the `Else` branch
      error("untagged cases cannot have `else` branch", field.nameIdent)

  # exception is raised only for the top level case field
  if raiseOnNone:
    let fieldNameLit = newLit field.nameIdent.strVal
    body.add quote do:
      `raiseUnknownUntaggedVariantSym`(`structNameLit`, `fieldNameLit`)
  result = body


template resolveTagged {.dirty.} =
  # HACK: need to generate temp let
  # to prove that case field value is correct
  let
    tempKindLetSym = genSym(nskLet, field.nameIdent.strVal)
    # get case field value from data
    tempKindLet = newLetStmt(tempKindLetSym, defGetField(field, raiseOnNone))

  addToObjConstr(objConstr, field.nameIdent, tempKindLetSym)
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
      var condition = copy variant.conditionOfBranch
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
    structNameLit = struct.typeSym.toStrLit

  var 
    objConstr = copy objConstr
    caseField = none Field
  
  for field in fields:
    if not field.features.skipDeserializing:
      if field.isCase:
        if caseField.isSome:
          # Must not be raised
          error("Object cannot contain more than one `case` expression at the same level", field.nameIdent)
        caseField = some field
      else:
        addToObjConstr(objConstr, field.nameIdent, defGetField(field, raiseOnNone))

  if caseField.isNone:
    # there is no case field, so just return statement
    result = nnkReturnStmt.newTree(objConstr)
  else:
    let field = caseField.unsafeGet

    if field.features.untagged:
      resolveUntagged
    else:
      resolveTagged

func addToObjConstr(objConstr, ident, value: NimNode) =
  # (ident: value)
  objConstr.add newColonExpr(ident, value)

func defGetField(field: Field, raiseOnNone: bool): NimNode =
  if Some(@defaultValueNode) ?= field.features.defaultValue:
    if defaultValueNode.kind == nnkEmpty:
      defGetOrDefault(field.nameIdent)
    else:
      defGetOrDefaultValue(field.nameIdent, defaultValueNode)
  elif raiseOnNone:  
    defGetOrRaise(field.nameIdent, defFieldNamesLit(field.deserializeName))
  else:
    defGetOrBreak(field.nameIdent)

func defGetOrDefault(fieldIdent: NimNode): NimNode =
  newCall(bindSym "getOrDefault", fieldIdent)

func defGetOrDefaultValue(fieldIdent: NimNode, defaultValue: NimNode): NimNode =
  newCall(bindSym "getOrDefaultValue", fieldIdent, defaultValue)

func defGetOrRaise(fieldIdent: NimNode, fieldName: NimNode): NimNode =
  newCall(bindSym "getOrRaise", fieldIdent, fieldName)

func defGetOrBreak(fieldIdent: NimNode): NimNode =
  newCall(bindSym "getOrBreak", fieldIdent)

func defVisitMapProc(struct: Struct, visitorType, body: NimNode): NimNode =
  var generics, returnType, visitorTyp: NimNode

  if struct.genericParams.isSome:
    generics = struct.genericParams.unsafeGet
    returnType = defWithGenerics(struct.typeSym, struct.genericParams.unsafeGet)
    visitorTyp = defWithGenerics(visitorType, struct.genericParams.unsafeGet)
  else:
    generics = newEmptyNode()
    returnType = struct.typeSym
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

func defOptionFieldVars(struct: Struct): NimNode =
  # var fieldName = none(FieldType)
  result = newStmtList()

  for field in struct.flattenFields:
    result.add newVarStmt(
      field.nameIdent,
      newCall(
        nnkBracketExpr.newTree(
          bindSym("none"),
          defFieldType(struct, field)
        )
      )
    )

func defForKeys(keyType, body: NimNode): NimNode =
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

func defKeyToValueCase(struct: Struct): NimNode =
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
      if field.features.deserializeWith.isSome or field.features.deserWith.isSome:
        let
          withType = field.nskTypeDeserializeWithSym
          originType = defFieldType(struct, field)
        nnkBracketExpr.newTree(
          withType,
          originType
        )
      else:
        defFieldType(struct, field)
    
    var nextValueCall =
      newCall(
        nnkBracketExpr.newTree(
          ident "nextValue",
          genericTypeArgument
        ),
        ident "map",
      )

    if field.features.deserializeWith.isSome or field.features.deserWith.isSome:
      nextValueCall = newDotExpr(nextValueCall, ident "value")

    let duplicateCheck =
      if struct.duplicateCheck:
        nnkIfStmt.newTree(
          nnkElifBranch.newTree(
            newCall(bindSym("isSome"), field.nameIdent),
            newStmtList(
              newCall(bindSym("raiseDuplicateField"), defFieldNamesLit(field.deserializeName))
            )
          )
        )
      else:
        newEmptyNode()

    result.add nnkOfBranch.newTree(
      newDotExpr(struct.nskTypeEnumSym, field.nskEnumFieldSym),
      newStmtList(
        duplicateCheck,
        newAssignment(
          field.nameIdent,
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

func defDeserializeValueProc(struct: Struct, body: NimNode, public: bool): NimNode =
  let
    deserializeProcIdent = defMaybeExportedIdent(ident "deserialize", public)
    selfType =
      if Some(@genericParams) ?= struct.genericParams:
        defwithGenerics(struct.typeSym, genericParams)
      else:
        struct.typeSym
  
  nnkProcDef.newTree(
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

func defValueDeserializeBody(struct: Struct, visitorType: NimNode): NimNode =
  let visitorType = (
    if Some(@genericParams) ?= struct.genericParams:
      defWithGenerics(visitorType, genericParams)
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
