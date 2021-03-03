import
  strformat,
  pragmas, macro_utils

proc genSkipIf(procIdent: NimNode, target: NimNode, actions: NimNode): NimNode =
  result = quote do:
    if not `procIdent`(`target`):
      `actions `

proc genWhenSkipIf(procIdent: NimNode, target: NimNode, actions: NimNode): NimNode =
  result = quote do:
    when compiles(`procIdent`(`target`)):
      if not `procIdent`(`target`):
        `actions `
    else:
      `actions`

proc addSerBlockActions(result: NimNode, target: NimNode, field: FieldDescription, keyVar: NimNode, valueVar: NimNode, actions: NimNode) =
  let name = field.renamed(Operation.Ser)
  let objSkipSerIf = field.skipSerializeIf
  let skipSerIf = field.pragmas.findPragma(bindSym"skipSerializeIf")
  let serWith = field.pragmas.findPragma(bindSym"serializeWith")
  var tempStmt = newStmtList()
  var tempTarget: NimNode
  if serWith.isNil:
    tempTarget = target
  else:
    let serWithProc = serWith[1]
    tempTarget = quote do:
      `serWithProc`(`target`)
  tempStmt.add quote do:
    block:
      template `keyVar`: untyped = `name`
      template `valueVar`: untyped = `tempTarget`
      `actions`

  if skipSerIf != nil:
    let skipIfProc = skipSerIf[1]
    result.add genSkipIf(skipIfProc, target, tempStmt)
  elif objSkipSerIf != nil:
    let skipIfProc = objSkipSerIf[1]
    result.add genWhenSkipIf(skipIfProc, target, tempStmt)
  else:
    result.add tempStmt

proc addForSer(result: NimNode, target: NimNode, keyVar: NimNode, valueVar: NimNode, fields: seq[FieldDescription], actions: NimNode) =
  for field in fields:
    if field.pragmas.findPragma(bindSym"skip") != nil or field.pragmas.findPragma(bindSym"skipSerializing") != nil:
      continue
    if field.isDiscriminator:
      if field.pragmas.findPragma(bindSym"untagged").isNil:
        result.addSerBlockActions(newDotExpr(target, field.name), field, keyVar, valueVar, actions)
      let cases = field.getCases()
      var caseStmt = nnkCaseStmt.newTree newDotExpr(target, field.name)
      for c in cases:
        var localStmt = newStmtList()
        localStmt.addForSer(target, keyVar, valueVar, c.fields, actions)
        case c.branch.kind
        of nnkOfBranch:
          caseStmt.add nnkOfBranch.newTree(c.branch[0], localStmt)
        of nnkElse:
          caseStmt.add nnkElse.newTree(localStmt)
        else:
          doAssert false
      result.add caseStmt
    else:
      if field.pragmas.findPragma(bindSym"flat").isNil:
        result.addSerBlockActions(newDotExpr(target, field.name), field, keyVar, valueVar, actions)
      else:
        let typeDesc = typeDescription(field.typ.getImpl)
        if typeDesc.pragmas.findPragma(bindSym"ser").isNil:
          error(fmt"Type `{typeDesc.name}` does not have the `ser` pragma", typeDesc.name)
        result.addForSer(newDotExpr(target, field.name), keyVar, valueVar, typeDescription(field.typ.getImpl).fields, actions)

macro forSer*(keyVar: untyped, valueVar: untyped, target: typed, actions: untyped) =
  result = newStmtList()
  initTypeInst()
  # not all types are serealizable, so we check for the presence of a pragma
  if typeDesc.pragmas.findPragma(bindSym"ser").isNil:
    error(fmt"Type `{$T}` does not have the `ser` pragma", T)

  result.addForSer(target, keyVar, valueVar, typeDesc.fields, actions)
  result = newStmtList(newBlockStmt(ident("serLoop"), result))

  if defined(debugDeser):
    echo "------------------------"
    echo fmt"Debug serialize for `{$T}` type"
    echo "------------------------"
    echo "forSer:"
    echo "------------------------"
    echo result.toStrLit
    echo "------------------------"
