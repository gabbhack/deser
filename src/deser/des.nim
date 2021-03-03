import
  options, strformat, macro_utils,
  results,
  error, pragmas


type
  DeserResult*[T] = Result[T, DeserError]

template getField*(field: Option, name: static[string]): untyped =
  when field.get.type is Option:
    flatten(field)
  else:
    if field.isNone():
      raise newException(MissingFieldError, static("Missing " & "\"" & name & "\"" & " field"))
    field.unsafeGet()

template getField*(field: Option, name: static[string], withDefault: typed{`proc`}): untyped =
  when field.get.type is Option:
    flatten(field)
  else:
    if field.isNone():
      withDefault(field.get.type)
    else:
      field.unsafeGet()

template checkField*(field: Option, name: static[string]) =
  if field.isNone():
    raise newException(MissingFieldError, static("Missing " & "\"" & name & "\"" & " field"))

proc genHideVar(name: string, typ: NimNode, pragmas: NimNode = nil): NimNode =
  var identExpr: NimNode
  if pragmas.isNil:
    identExpr = ident(name & "Hide")
  else:
    identExpr = nnkPragmaExpr.newTree(ident(name & "Hide"), pragmas)
  nnkVarSection.newTree(
    nnkIdentDefs.newTree(
      identExpr,
      nnkBracketExpr.newTree(
        ident("Option"),
        typ
      ),
      newEmptyNode()
    )
  )

proc genGetField(field: FieldDescription): NimNode =
  let varName = ident(field.name.strVal & "Hide")
  let withDefault = field.pragmas.findPragma(bindSym"withDefault")
  if withDefault.isNil:
    result = newStmtList(nnkCall.newTree(
      ident "getField",
      varName,
      field.renamed()
    ))
  else:
    result = newStmtList(nnkCall.newTree(
      ident "getField",
      varName,
      field.renamed(),
      withDefault[1]
    ))

proc genNoAnyVariantError(typeName: string, discriminatorName: string): NimNode = 
  let typeName = typeName
  let discriminatorName = discriminatorName
  let errorMsg = fmt"Data did not match any variant of `untagged` discriminator `{discriminatorName}` of type `{typeName}`"

  result = quote do:
    raise newException(NoAnyVariantError, `errorMsg`)

proc checkCases(T: NimNode, fields: seq[FieldDescription]) =
  var casesCount = 0
  for field in fields:
    if field.isDiscriminator:
      if casesCount == 0:
        inc casesCount
        checkCases(T, field.subFields)
      else:
        error(fmt"The `{$T}` type has more than one `case` on the same level: `{$field.name}`.")

proc addHideVars(result: NimNode, fields: seq[FieldDescription]) =
  for field in fields:
    if field.pragmas.findPragma(bindSym"skip") != nil or field.pragmas.findPragma(bindSym"skipDeserializing") != nil:
      continue
    if field.pragmas.findPragma(bindSym"flat") != nil:
      let typeDesc = typeDescription(field.typ.getImpl)
      if typeDesc.pragmas.findPragma(bindSym"des").isNil:
        error(fmt"Type `{typeDesc.name}` does not have the `des` pragma", typeDesc.name)
      checkCases(typeDesc.name, typeDesc.fields)
      result.addHideVars typeDesc.fields
    else:
      if field.isDiscriminator:
        if field.pragmas.findPragma(bindSym"untagged").isNil:
          result.add genHideVar(field.name.strVal, field.typ)
        result.addHideVars field.subFields
      else:
        result.add genHideVar(field.name.strVal, field.typ)

proc addAsgn(result: NimNode, varName: NimNode, fieldName: NimNode, varResult: NimNode) =
  result.add nnkAsgn.newTree(nnkDotExpr.newTree(varName, fieldName), varResult)

proc addObjectCreate(result: NimNode, T: NimNode, target: NimNode, fields: seq[FieldDescription], objConstr: NimNode = nil, asgnStmt: NimNode = nil) =
  if asgnStmt.isNil:
    var asgnStmt = newStmtList()
    addObjectCreate(result, T, target, fields, objConstr, asgnStmt)
    return
  
  # first, we check the "required" fields at the current level
  # required means that they are outside the "case"
  for field in fields:
    if field.pragmas.findPragma(bindSym"skip") != nil or field.pragmas.findPragma(bindSym"skipDeserializing") != nil:
      continue
    if not field.isDiscriminator:
      if field.pragmas.findPragma(bindSym"flat") != nil:
        var tempStmt = newStmtList()
        addObjectCreate(tempStmt, field.typ, newDotExpr(target, field.name), typeDescription(field.typ.getImpl).fields)
        asgnStmt.add tempStmt
      else:
        asgnStmt.addAsgn(target, field.name, genGetField(field))
  
  var hasDiscriminator = false
  for field in fields:
    if field.pragmas.findPragma(bindSym"skip") != nil or field.pragmas.findPragma(bindSym"skipDeserializing") != nil:
      continue
    if field.isDiscriminator:
      hasDiscriminator = true
      # simulation of a hash table
      let cases = field.getCases()
      
      template initLocals() {.dirty.} =
        var localStmt = newStmtList()

        var localObjConstr: NimNode
        if objConstr.isNil:
          localObjConstr = nnkObjConstr.newTree(newCall("typeof", target))
        else:
          localObjConstr = copy objConstr

        var localAsgnStmt: NimNode
        if asgnStmt.isNil:
          localAsgnStmt = newStmtList()
        else:
          localAsgnStmt = copy asgnStmt

      if field.pragmas.findPragma(bindSym"untagged").isNil:
        var caseStmt = nnkCaseStmt.newTree genGetField(field)
        for c in cases:
          initLocals()

          localObjConstr.add nnkExprColonExpr.newTree(
            field.name,
            genGetField(field)
          )

          addObjectCreate(localStmt, T, target, c.fields, localObjConstr, localAsgnStmt)
          case c.branch.kind
          of nnkOfBranch:
            caseStmt.add nnkOfBranch.newTree(c.branch[0], localStmt)
          of nnkElse:
            caseStmt.add nnkElse.newTree(localStmt)
          else:
            doAssert false
        result.add caseStmt
      else:
        var stmts: seq[NimNode] = @[]
        for c in cases:
          initLocals()

          case c.branch.kind
          of nnkOfBranch:
            case c.branch[0].kind
            of {nnkCharLit..nnkNilLit, nnkSym, nnkIdent, nnkDotExpr}:
              localObjConstr.add nnkExprColonExpr.newTree(
                field.name,
                c.branch[0]
              )
            else:
              error(fmt"`untagged` discriminator (`{$T}.{field.name.strVal}`) supports only literals as a `case` branch", c.branch)
          else:
            error(fmt"`untagged` discriminator (`{$T}.{field.name.strVal}`) do not supports `else` branches", c.branch)

          addObjectCreate(localStmt, T, target, c.fields, localObjConstr, localAsgnStmt)
          stmts.add localStmt

        var tryStmt: NimNode
        for i in countdown(high(stmts), 0):
          var localTryStmt = nnkTryStmt.newTree()
          localTryStmt.add stmts[i]
          localTryStmt.add nnkExceptBranch.newTree(
            ident("UntaggemableError"),
            if i == high(stmts): genNoAnyVariantError($T, field.name.strVal) else: tryStmt
          )
          tryStmt = localTryStmt
        result.add tryStmt

  # do not generate extra code if there is a "case"
  if not hasDiscriminator:
    if objConstr != nil:
      result.add nnkAsgn.newTree(target, objConstr)
    result.add asgnStmt

proc addDesBlockActions(result: NimNode, field: FieldDescription, keyVar: NimNode, valueVar: NimNode, actions: NimNode) =
  let name = field.renamed()
  let hideVar = ident(field.name.strVal & "Hide")
  let deserWith = field.pragmas.findPragma(bindSym"deserializeWith")
  if deserWith.isNil:
    result.add quote do:
      block:
        template `keyVar`: untyped = `name`
        template `valueVar`: untyped = `hideVar`
        `actions`
  else:
    let deserWithProc = deserWith[1]
    let deserWithProcParams = deserWithProc.getTypeInst[0]
    if deserWithProcParams[0].kind == nnkEmpty:
      error("`deserializeWith` procedure must have return type", deserWithProc)
    if deserWithProcParams.len == 1:
      error("`deserializeWith` procedure must have at least one parameter", deserWithProc)
    let varType = deserWithProcParams[1][1]
    let returnType = deserWithProcParams[0]
    if returnType == field.typ:
      result.add quote do:
        block:
          template `keyVar`: untyped = `name`
          var `valueVar`: `varType`
          try:
            `actions`
          finally:
            `hideVar` = some(`deserWithProc`(`valueVar`))
    else:
      error(fmt"The return type of `{deserWithProc.strVal}` ({returnType.strVal}) does not match the field type ({field.typ.strVal})", deserWithProc)

proc addForDes(result: NimNode, keyVar: NimNode, valueVar: NimNode, fields: seq[FieldDescription], actions: NimNode) =
  for field in fields:
    if field.pragmas.findPragma(bindSym"skip") != nil or field.pragmas.findPragma(bindSym"skipDeserializing") != nil:
      continue
    if field.isDiscriminator:
      if field.pragmas.findPragma(bindSym"untagged").isNil:
        result.addDesBlockActions(field, keyVar, valueVar, actions)
      result.addForDes(keyVar, valueVar, field.subFields, actions)
    else:
      if field.pragmas.findPragma(bindSym"flat").isNil:
        result.addDesBlockActions(field, keyVar, valueVar, actions)
      else:
        result.addForDes(keyVar, valueVar, typeDescription(field.typ.getImpl).fields, actions)

macro startDes*(target: typed, actions: untyped) =
  result = newStmtList()
  initTypeInst()

  # not all types are deserealizable, so we check for the presence of a pragma
  if typeDesc.pragmas.findPragma(bindSym"des").isNil:
    error(fmt"Type `{$T}` does not have the `des` pragma", T)

  let fields = typeDesc.fields

  #[
    Deser does not support multiple "cases" at the same level:
    First of all, it's not really necessary. 
    Second, this is only possible with ARC/ORC (https://github.com/nim-lang/RFCs/issues/209).
    Third, the library will have to generate not very efficient code.
  ]#
  checkCases(T, fields)

  result.addHideVars fields

  # add user actions
  result.add actions

  result.addObjectCreate(T, target, fields)
  if defined(debugDeser):
    echo "------------------------"
    echo fmt"Debug deserialize for `{$T}` type"
    echo "------------------------"
    echo "startDes:"
    echo "------------------------"
    echo result.toStrLit
    echo "------------------------"

macro forDes*(keyVar: untyped, valueVar: untyped, target: typed, actions: untyped) =
  result = newStmtList()
  initTypeInst()
  result.addForDes(keyVar, valueVar, typeDesc.fields, actions)
  result = newStmtList(newBlockStmt(ident("desLoop"), result))

  if defined(debugDeser):
    echo "forDes:"
    echo "------------------------"
    echo result.toStrLit
    echo "------------------------"
