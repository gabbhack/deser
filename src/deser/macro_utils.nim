import
  macros, strformat, sequtils, sugar,
  anycase_fork,
  pragmas

export macros

type
  Operation* {.pure.} = enum
    Ser, Des

  Case* = tuple[branch: NimNode, fields: seq[FieldDescription]]

  TypeDescription* = object
    name*: NimNode
    pragmas*: NimNode
    fields: seq[FieldDescription]

  FieldDescription* = object
    name*: NimNode
    isPublic*: bool
    typ*: NimNode
    pragmas*: NimNode
    caseField*: NimNode
    caseBranch*: NimNode

    skipSerializeIf*: NimNode
    renameAll*: NimNode
    asOption*: bool

    case isDiscriminator*: bool
    of true:
      subFields*: seq[FieldDescription]
    else:
      discard

const
  nnkPragmaCallKinds = {nnkExprColonExpr, nnkCall, nnkCallStrLit}

{.push compileTime.}

proc renamer(x: string, rule: string): string =
  case rule
  of "rkCamelCase":
    camel(x)
  of "rkSnakeCase":
    snake(x)
  of "rkKebabCase":
    kebab(x)
  of "rkPascalCase":
    pascal(x)
  of "rkUpperSnakeCase":
    upperSnake(x)
  of "rkUpperKebabCase":
    cobol(x)
  else:
    x

proc asStr*(x: NimNode): string =
  case x.kind
  of nnkBracketExpr:
    result = x.toStrLit.strval
  of nnkIdent, nnkSym:
    result = x.strVal
  of nnkPostfix:
    result = x[1].strVal
  of nnkLiterals:
    result = x.strVal
  of nnkAccQuoted:
    result = x[0].asStr
  else:
    error(fmt"Invalid kind `{x.kind}` of node: {x.toStrLit}", x)

proc findPragma*(pragmas: NimNode, pragmaSym: NimNode): NimNode =
  for p in pragmas:
    if p.kind in {nnkSym, nnkIdent} and eqIdent(p, pragmaSym):
      return p
    if p.kind in nnkPragmaCallKinds and p.len > 0 and eqIdent(p[0], pragmaSym):
      return p

proc collectFieldsFromRecList(result: var seq[FieldDescription],
                              n: NimNode,
                              parentCaseField: NimNode = nil,
                              parentCaseBranch: NimNode = nil,
                              isDiscriminator = false) =
  case n.kind
  of nnkRecList:
    for entry in n:
      collectFieldsFromRecList result, entry,
                               parentCaseField, parentCaseBranch

  of nnkRecWhen:
    for branch in n:
      case branch.kind:
      of nnkElifBranch:
        collectFieldsFromRecList result, branch[1],
                                 parentCaseField, parentCaseBranch
      of nnkElse:
        collectFieldsFromRecList result, branch[0],
                                 parentCaseField, parentCaseBranch
      else:
        doAssert false

  of nnkRecCase:
    collectFieldsFromRecList result, n[0],
                             parentCaseField,
                             parentCaseBranch,
                             isDiscriminator = true
    let fieldIndex = high(result)
    var field = result[fieldIndex]
    for i in 1 ..< n.len:
      # TODO support discard in else or of
      let branch = n[i]
      case branch.kind
      of nnkOfBranch:
        collectFieldsFromRecList field.subFields, branch[^1], n[0], branch
      of nnkElse:
        collectFieldsFromRecList field.subFields, branch[0], n[0], branch
      else:
        doAssert false
    result[fieldIndex] = field
  of nnkIdentDefs:
    let fieldType = n[^2]
    for i in 0 ..< n.len - 2:
      var field: FieldDescription
      field.name = n[i]
      field.typ = fieldType
      field.caseField = parentCaseField
      field.caseBranch = parentCaseBranch
      field.isDiscriminator = isDiscriminator

      if field.name.kind == nnkPragmaExpr:
        field.pragmas = field.name[1]
        field.name = field.name[0]

      elif field.name.kind == nnkPostfix:
        field.isPublic = true
        field.name = field.name[1]

      result.add field

  of nnkSym:
    result.add FieldDescription(
      name: n,
      typ: getType(n),
      caseField: parentCaseField,
      caseBranch: parentCaseBranch,
      isDiscriminator: isDiscriminator)

  of nnkNilLit, nnkDiscardStmt, nnkCommentStmt, nnkEmpty:
    discard

  else:
    doAssert false, "Unexpected nodes in recordFields:\n" & n.treeRepr

proc collectFieldsInHierarchy(result: var seq[FieldDescription],
                              objectType: NimNode) =
  var objectType = objectType

  objectType.expectKind {nnkObjectTy, nnkRefTy}

  if objectType.kind == nnkRefTy:
    objectType = objectType[0]

  objectType.expectKind nnkObjectTy

  var baseType = objectType[1]
  if baseType.kind != nnkEmpty:
    baseType.expectKind nnkOfInherit
    baseType = baseType[0]
    baseType.expectKind nnkSym
    baseType = getImpl(baseType)
    baseType.expectKind nnkTypeDef
    baseType = baseType[2]
    baseType.expectKind {nnkObjectTy, nnkRefTy}
    collectFieldsInHierarchy result, baseType

  let recList = objectType[2]
  collectFieldsFromRecList result, recList

proc replaceTypes(x: var seq[FieldDescription], y: var seq[FieldDescription]) =
  for i in countup(0, high(x)):
    if x[i].typ != y[i].typ:
      x[i].typ = y[i].typ
    if x[i].isDiscriminator:
      # create temp vars because of strange bug
      var tx = x[i].subFields
      var ty = y[i].subFields
      replaceTypes(tx, ty)
      x[i].subFields = tx
      y[i].subFields = ty

proc addRenameAll(x: var seq[FieldDescription], renameAll: NimNode) =
  for i in countup(0, high(x)):
    x[i].renameAll = renameAll

    if x[i].isDiscriminator:
      addRenameAll(x[i].subFields, renameAll)

proc addSkipSerializeIf(x: var seq[FieldDescription],
    skipSerializeIf: NimNode) =
  for i in countup(0, high(x)):
    x[i].skipSerializeIf = skipSerializeIf

    if x[i].isDiscriminator:
      addSkipSerializeIf(x[i].subFields, skipSerializeIf)

proc typeDescription*(typeDef: NimNode, objectTy: NimNode = nil): TypeDescription =
  typeDef.expectKind nnkTypeDef
  if objectTy != nil:
    case objectTy.kind
    of {nnkTupleTy, nnkRefTy}:
      error("Deser does not supports tuples or ref types", objectTy)
    else:
      objectTy.expectKind nnkObjectTy
  typeDef[0].expectKind {nnkSym, nnkPragmaExpr}
  case typeDef[0].kind
  of nnkSym:
    result.name = typeDef[0]
    result.pragmas = nil
  of nnkPragmaExpr:
    result.name = typeDef[0][0]
    result.pragmas = typeDef[0][1]
  else:
    doAssert false

  collectFieldsInHierarchy(result.fields, typeDef[2])

  if objectTy != nil:
    var tempTypeDes: TypeDescription
    collectFieldsInHierarchy(tempTypeDes.fields, objectTy)
    replaceTypes(result.fields, tempTypeDes.fields)

  let renameAll = result.pragmas.findPragma(bindSym"renameAll")
  let skipSerializeIf = result.pragmas.findPragma(bindSym"skipSerializeIf")

  if renameAll != nil:
    addRenameAll(result.fields, renameAll)

  if skipSerializeIf != nil:
    addSkipSerializeIf(result.fields, skipSerializeIf)

template initTypeInst*() {.dirty.} =
  let typeInst = target.getTypeInst
  var T: NimNode
  case typeInst.kind
  of nnkSym:
    T = typeInst
  of nnkBracketExpr:
    T = target.getTypeInst[0]
  else:
    error(fmt"Invalid sym kind: {typeInst.kind}")
  let impl = T.getImpl()
  let typeDesc = typeDescription(impl, target.getTypeImpl())

proc checkCases(T: NimNode, fields: seq[FieldDescription]) =
  var casesCount = 0
  for field in fields:
    if field.isDiscriminator:
      if casesCount == 0:
        inc casesCount
        checkCases(T, field.subFields)
      else:
        error(fmt"The `{$T}` type has more than one `case` on the same level: `{field.name.asStr}`.", T)

proc check*(desc: TypeDescription, op: Operation) =
  case op
  of Des:
    if desc.pragmas.findPragma(bindSym"des").isNil:
      error(fmt"Type `{$desc.name}` does not have the `des` pragma", desc.name)
  of Ser:
    if desc.pragmas.findPragma(bindSym"ser").isNil:
      error(fmt"Type `{$desc.name}` does not have the `ser` pragma", desc.name)

  checkCases(desc.name, desc.fields)

proc isFlat*(field: FieldDescription): bool = field.pragmas.findPragma(
    bindSym"flat") != nil

proc isUntagged*(field: FieldDescription): bool = field.pragmas.findPragma(
    bindSym"untagged") != nil

proc hasWithDefault*(field: FieldDescription): bool = field.pragmas.findPragma(
    bindSym"withDefault") != nil

proc getWithDefault*(field: FieldDescription): NimNode = field.pragmas.findPragma(bindSym"withDefault")

proc hasDeserWith*(field: FieldDescription): bool = field.pragmas.findPragma(
    bindSym"deserializeWith") != nil

proc getDeserWith*(field: FieldDescription): (NimNode, NimNode) =
  result = (nil, nil)
  let deserWith = field.pragmas.findPragma(bindSym"deserializeWith")
  if deserWith != nil:
    let deserWithProc = deserWith[1]
    let deserWithProcParams = deserWithProc.getTypeInst[0]
    if deserWithProcParams[0].kind == nnkEmpty:
      error("`deserializeWith` procedure must have return type", deserWithProc)
    if deserWithProcParams.len == 1:
      error("`deserializeWith` procedure must have at least one parameter", deserWithProc)
    let varType = deserWithProcParams[1][1]
    let returnType = deserWithProcParams[0]
    if returnType != field.typ:
      error(fmt"The return type of `{deserWithProc.asStr}` ({returnType.asStr}) does not match the field type ({field.typ.asStr})", deserWithProc)
    else:
      result = (deserWithProc, varType)

proc getSkipSerIf*(field: FieldDescription): NimNode = field.pragmas.findPragma(bindSym"skipSerializeIf")

proc getSerWith*(field: FieldDescription): NimNode = field.pragmas.findPragma(bindSym"serializeWith")

proc optionaizer(fields: var seq[FieldDescription]) =
  for field in mitems(fields):
    if field.isDiscriminator:
      optionaizer(field.subFields)
    if not field.isUntagged:
      field.asOption = true

proc hasUntagged*(fields: seq[FieldDescription]): bool = any(fields, (field) =>
    field.isUntagged and field.isDiscriminator)

proc fields*(desc: TypeDescription | FieldDescription, op: Operation): seq[
    FieldDescription] =
  when desc is TypeDescription:
    var fields = desc.fields
  else:
    var fields = desc.subFields

  var secondSkip: NimNode
  case op
  of Des:
    secondSkip = bindSym"skipDeserializing"
  of Ser:
    secondSkip = bindSym"skipSerializing"

  when desc is TypeDescription:
    if fields.hasUntagged:
      for field in mitems(fields):
        if field.isDiscriminator:
          optionaizer(field.subFields)

  for field in fields:
    if field.pragmas.findPragma(bindSym"skip").isNil and
        field.pragmas.findPragma(secondSkip).isNil:
      result.add field

proc hideIdent*(field: FieldDescription): NimNode = ident(field.name.asStr & "Hide")

proc nameIdent*(field: FieldDescription): NimNode = ident(field.name.asStr)

proc getTypeDesc*(target: NimNode | FieldDescription,
    op: Operation): TypeDescription =
  when target is NimNode:
    let typeInst = target.getTypeInst
    var T: NimNode
    case typeInst.kind
    of nnkSym:
      T = typeInst
    of nnkBracketExpr:
      T = target.getTypeInst[0]
    else:
      error(fmt"Invalid sym kind: {typeInst.kind}")
    let impl = T.getImpl()
    result = typeDescription(impl, target.getTypeImpl())
  else:
    result = typeDescription(target.typ.getImpl)
  result.check(op)

proc renamed*(field: FieldDescription, op: Operation): NimNode =
  let rename = field.pragmas.findPragma(bindSym"rename")
  let renameAll = field.renameAll
  if rename != nil:
    case op
    of Des:
      if rename[1].asStr.len > 0 and rename[2].asStr.len == 0:
        return newLit rename[1].asStr
      elif rename[2].asStr.len > 0:
        return newLit rename[2].asStr
      else:
        return newLit field.name.asStr
    of Ser:
      if rename[1].asStr.len > 0:
        return newLit rename[1].asStr
      else:
        return newLit field.name.asStr
  elif renameAll != nil:
    case op
    of Des:
      if renameAll[1].asStr != "rkNothing" and renameAll[2].asStr == "rkNothing":
        return newLit renamer(field.name.asStr, renameAll[1].asStr)
      else:
        return newLit renamer(field.name.asStr, renameAll[2].asStr)
    of Ser:
      return newLit renamer(field.name.asStr, renameAll[1].asStr)
  else:
    return newLit field.name.asStr

proc getCases*(field: FieldDescription, op: Operation): seq[Case] =
  for f in field.fields(op):
    var caseId = -1
    for i, c in result:
      if c.branch == f.caseBranch:
        caseId = i
    if caseId != -1:
      result[caseId].fields.add f
    else:
      result.add (branch: f.caseBranch, fields: @[f])

{.pop.}
