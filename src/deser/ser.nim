import
  strformat,
  macro_utils

proc genForSer(target, key, value: NimNode, fields: seq[FieldDescription],
    actions: NimNode): NimNode

proc genSkipIf(procIdent: NimNode, target: NimNode, actions: NimNode): NimNode =
  result = quote do:
    if not `procIdent`(`target`):
      `actions`

proc genWhenSkipIf(procIdent: NimNode, target: NimNode,
    actions: NimNode): NimNode =
  let skipIf = genSkipIf(procIdent, target, actions)
  result = quote do:
    when compiles(`procIdent`(`target`)):
      `skipIf`
    else:
      `actions`

proc genSerBlock(field: FieldDescription, target, key, value,
    actions: NimNode): NimNode =
  result = newStmtList()

  let
    name = field.renamed(Operation.Ser)
    objSkipSerIf = field.skipSerializeIf
    skipSerIf = field.getSkipSerIf()
    serWith = field.getSerWith()
    tempStmt = newStmtList()

  var tempTarget: NimNode

  if serWith.isNil:
    tempTarget = target
  else:
    let serWithProc = serWith[1]
    tempTarget = quote do:
      `serWithProc`(`target`)

  tempStmt.add quote do:
    block:
      template `key`: untyped = `name`
      template `value`: untyped = `tempTarget`
      `actions`

  if skipSerIf != nil:
    let skipIfProc = skipSerIf[1]
    result.add genSkipIf(skipIfProc, target, tempStmt)
  elif objSkipSerIf != nil:
    let skipIfProc = objSkipSerIf[1]
    result.add genWhenSkipIf(skipIfProc, target, tempStmt)
  else:
    result.add tempStmt

proc genCaseStmt(field: FieldDescription, target, key, value,
    actions: NimNode): NimNode =
  result = nnkCaseStmt.newTree newDotExpr(target, field.nameIdent)
  let cases = field.getCases(Ser)

  for c in cases:
    var localStmt = genForSer(target, key, value, c.fields, actions)
    case c.branch.kind
    of nnkOfBranch:
      let localBranch = nnkOfBranch.newTree()
      localBranch.add c.branch[0..^2]
      localBranch.add localStmt
      result.add localBranch
    of nnkElse:
      result.add nnkElse.newTree(localStmt)
    else:
      doAssert false

proc genForSer(target, key, value: NimNode, fields: seq[FieldDescription],
    actions: NimNode): NimNode =
  result = newStmtList()

  for field in fields:
    if field.isDiscriminator:
      if not field.isUntagged:
        result.add genSerBlock(field, newDotExpr(target, field.nameIdent), key,
            value, actions)
      result.add genCaseStmt(field, target, key, value, actions)
    else:
      if field.isFlat:
        let typeDesc = field.getTypeDesc(Ser)
        result.add genForSer(newDotExpr(target, field.nameIdent), key, value,
            typeDesc.fields(Ser), actions)
      else:
        result.add genSerBlock(field, newDotExpr(target, field.nameIdent), key,
            value, actions)

macro forSer*(key, value: untyped, target: typed, actions: untyped) =
  result = newStmtList()

  let
    typeDesc = target.getTypeDesc(Ser)
    fields = typeDesc.fields(Ser)

  result.add genForSer(target, key, value, fields, actions)

  result = newStmtList(newBlockStmt(ident("serLoop"), result))

  if defined(debug):
    echo fmt"forSer for `{$typeDesc.name}` type:"
    echo "------------------------"
    echo result.toStrLit
    echo "------------------------"
