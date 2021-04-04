import
  options, strformat, sugar, sequtils,
  results, macro_utils,
  errors, pragmas

type
  DeserResult*[T] = Result[T, string]


template getField*[T](field: DeserResult[T]): T =
  # In general, if the macro generated the correct IFs,
  # `get` should not affect performance,
  # since the compiler is smart enough and does not perform the additional check that `get` does
  when defined(danger) or defined(deserDisableSafeGet):
    field.unsafeGet()
  else:
    field.get()

template getField*[T](field: DeserResult[T], withDefault: T): T =
  field.valueOr(withDefault)

template getField*[T](field: Option[T]): T =
  when defined(danger) or defined(deserDisableSafeGet):
    field.unsafeGet()
  else:
    field.get()

template getField*[T](field: Option[T], withDefault: T): T =
  if field.isNone:
    withDefault
  else:
    field.unsafeGet()

template checkField*(field: Option | DeserResult): bool =
  when field is Option:
    field.isSome
  else:
    field.isOk

proc genHideVar(field: FieldDescription, asOption: bool): NimNode =
  let
    identExpr = field.hideIdent
    name = field.renamed(Des)
    (deserWith, deserWithVarType) = field.getDeserWith()

  var typ =
    if deserWith.isNil:
      field.typ
    else:
      deserWithVarType

  # optimization for fields under `untagged` case
  # we don't care about a error, it only matters if there is the field or not
  if asOption:
    result = quote do:
      when `typ` is Option:
        var `identExpr` = default(type(`typ`))
      else:
        var `identExpr` = none(type(`typ`))
  else:
    let
      missingFieldError = fmt"Missing `{name}` field"
      impossibleError = ""
    result = quote do:
      when `typ` is Option:
        var `identExpr` = DeserResult[`typ`].err(`impossibleError`)
      else:
        var `identExpr` = DeserResult[`typ`].err(`missingFieldError`)

proc genHideVars(fields: seq[FieldDescription]): NimNode =
  result = newStmtList()

  for field in fields:
    if field.isFlat:
      let typeDesc = field.getTypeDesc(Des)
      result.add genHideVars(typeDesc.fields(Des))
    else:
      if field.isDiscriminator:
        if not field.isUntagged:
          result.add genHideVar(field, field.asOption)
        result.add genHideVars(field.fields(Des))
      else:
        result.add genHideVar(field, field.asOption)

proc genErrorCheckOnRequired(fields: seq[FieldDescription]): NimNode =
  result = newStmtList()

  for field in fields.filter((field) => not field.isUntagged):
    if field.isFlat:
      result.add genErrorCheckOnRequired(getTypeDesc(field, Des).fields(Des))
    else:
      let identExpr = field.hideIdent
      if not field.hasWithDefault:
        result.add quote do:
          if `identExpr`.isErr:
            raise newException(FieldDeserializationError,
                `identExpr`.unsafeError())

proc genAsgn(target: NimNode, fieldName: NimNode, varResult: NimNode): NimNode =
  result = newAssignment(nnkDotExpr.newTree(target, fieldName), varResult)

proc genGetField(field: FieldDescription): NimNode =
  let
    varName = field.hideIdent
    withDefault = field.getWithDefault()
    (deserWith, _) = field.getDeserWith()

  if withDefault.isNil:
    result = newCall(
      ident "getField",
      varName
    )
  elif withDefault[1].isNil:
    result = newCall(
      ident "getField",
      varName,
      newCall("default", newDotExpr(field.typ, ident("type")))
    )
  else:
    result = newCall(
      ident "getField",
      varName,
      withDefault[1]
    )

  if deserWith != nil:
    result = newCall(
      deserWith,
      result
    )

proc genInfix(first, second: NimNode, keyword: string): NimNode =
  result = nnkInfix.newTree(ident(keyword), first, second)

proc genCheckField(field: FieldDescription): NimNode =
  result = newCall(ident "checkField", field.hideIdent)

proc genElifCondition(fields: seq[FieldDescription]): NimNode =
  result = nil

  for field in fields.filter((x) => not x.isDiscriminator):
    if result.isNil:
      if field.isFlat:
        result = genElifCondition(getTypeDesc(field, Des).fields(Des))
      else:
        result = field.genCheckField()
    else:
      if field.isFlat:
        result = genInfix(result, genElifCondition(getTypeDesc(field,
            Des).fields(Des)), "and")
      else:
        result = genInfix(result, field.genCheckField(), "and")

  for field in fields.filter((x) => x.isDiscriminator):
    if not field.isUntagged:
      if result.isNil:
        result = field.genCheckField()
      else:
        result = genInfix(result, field.genCheckField(), "and")

    var orStmt: NimNode = nil
    for c in field.getCases(Des):
      if orStmt.isNil:
        orStmt = genElifCondition(c.fields)
      else:
        orStmt = genInfix(orStmt, genElifCondition(c.fields), "or")
    if result.isNil:
      result = orStmt
    else:
      result = genInfix(result, orStmt, "and")

proc genNoAnyVariantError(typeName: string,
    discriminatorName: string): NimNode =
  let
    typeName = typeName
    discriminatorName = discriminatorName
    errorMsg = fmt"Data did not match any variant of `untagged` discriminator `{discriminatorName}` of type `{typeName}`"

  result = quote do:
    raise newException(NoAnyVariantError, `errorMsg`)

proc foldObjectBody(target: NimNode, T: NimNode, fields: seq[FieldDescription],
    objConstr: NimNode = nil, asgnStmt: NimNode = newStmtList(),
    insideUntagged = false): NimNode =
  result = newStmtList()

  # immediately interrupt the deserialization process if there are no required fields
  if not insideUntagged:
    result.add genErrorCheckOnRequired(fields)

  for field in fields.filter((x) => not x.isDiscriminator):
    if field.isFlat:
      asgnStmt.add foldObjectBody(newDotExpr(target, field.nameIdent),
          field.typ, getTypeDesc(field, Des).fields(Des),
          insideUntagged = insideUntagged)
    else:
      asgnStmt.add genAsgn(target, field.nameIdent, genGetField(field))

  let
    discriminatorSeq = fields.filter((x) => x.isDiscriminator)
    # not `> 0`, because must be only one `case` per level
    hasDiscriminator = discriminatorSeq.len == 1

  if hasDiscriminator:
    let
      discriminator = discriminatorSeq[0]
      cases = discriminator.getCases(Des)

    if discriminator.isUntagged:
      var ifStmt = nnkIfStmt.newTree()

      for n, c in cases:
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

        case c.branch.kind
        of nnkOfBranch:
          case c.branch[0].kind
          of {nnkCharLit..nnkNilLit, nnkSym, nnkIdent, nnkDotExpr}:
            localObjConstr.add nnkExprColonExpr.newTree(
              ident(discriminator.name.asStr),
              c.branch[0]
            )
          else:
            error(fmt"`untagged` discriminator (`{$T}.{discriminator.name.asStr}`) supports only literals as a `case` branch", c.branch)
        else:
          error(fmt"`untagged` discriminator (`{$T}.{discriminator.name.asStr}`) do not supports `else` branches", c.branch)

        let localStmt = foldObjectBody(target, T, c.fields, localObjConstr,
            localAsgnStmt, true)

        # dont check the last case again, just "else"
        if n == high(cases) and insideUntagged:
          ifStmt.add nnkElse.newTree(localStmt)
        else:
          ifStmt.add nnkElifBranch.newTree(genElifCondition(c.fields), localStmt)

      if not insideUntagged:
        ifStmt.add nnkElse.newTree(genNoAnyVariantError($T,
            discriminator.name.asStr))
      result.add ifStmt
    else:
      var caseStmt = nnkCaseStmt.newTree genGetField(discriminator)
      for c in cases:
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

        localObjConstr.add nnkExprColonExpr.newTree(
          ident(discriminator.name.asStr),
          genGetField(discriminator)
        )

        let localStmt = foldObjectBody(target, T, c.fields, localObjConstr,
            localAsgnStmt, insideUntagged = insideUntagged)
        case c.branch.kind
        of nnkOfBranch:
          let localBranch = nnkOfBranch.newTree()
          localBranch.add c.branch[0..^2]
          localBranch.add localStmt
          caseStmt.add localBranch
        of nnkElse:
          caseStmt.add nnkElse.newTree(localStmt)
        else:
          doAssert false
      result.add caseStmt
  else:
    if objConstr != nil:
      result.add newAssignment(target, objConstr)
    result.add asgnStmt

proc genDesBlock(field: FieldDescription, key, value,
    actions: NimNode): NimNode =
  result = newStmtList()

  let
    name = field.renamed(Des)
    hideIdent = field.hideIdent
    duplicateError = fmt"A duplicate of the `{name}` field was found in the data."
    deserError = fmt"""An error occurred while deserializing the `{name}` field: """

  result.add quote do:
    block:
      template `key`: untyped = `name`

      when `hideIdent` is DeserResult:
        when type(`hideIdent`.get) is Option:
          var `value`: type(`hideIdent`.get)
        else:
          var `value`: Option[type(`hideIdent`.get)]
      else:
        template `value`: untyped = `hideIdent`

      template finish(a: untyped): untyped =
        block:
          try:
            when not (defined(deserDisableDuplicationCheck) or defined(danger)):
              when `hideIdent` is DeserResult:
                if `hideIdent`.isOk:
                  `hideIdent`.err(`duplicateError`)
                  break
              else:
                if `hideIdent`.isSome:
                  `hideIdent` = default(type(`hideIdent`))
                  break
            a
            when `hideIdent` is DeserResult:
              when type(`hideIdent`.get) is Option:
                `hideIdent`.ok(`value`)
              else:
                if `value`.isSome:
                  `hideIdent`.ok(`value`.unsafeGet())
          except CatchableError:
            when `hideIdent` is DeserResult:
              `hideIdent`.err(`deserError` & getCurrentExceptionMsg())
            else:
              `hideIdent` = default(type(`hideIdent`))
      `actions`

proc genForDes(key, value: NimNode, fields: seq[FieldDescription],
    actions: NimNode): NimNode =
  result = newStmtList()

  for field in fields:
    if field.isDiscriminator:
      if not field.isUntagged:
        result.add genDesBlock(field, key, value, actions)
      result.add genForDes(key, value, field.fields(Des), actions)
    else:
      if field.isFlat:
        result.add genForDes(key, value, field.getTypeDesc(Des).fields(Des), actions)
      else:
        result.add genDesBlock(field, key, value, actions)

macro startDes*(target: typed, actions: untyped) =
  result = newStmtList()

  let
    typeDesc = target.getTypeDesc(Des)
    fields = typeDesc.fields(Des)

  result.add genHideVars(fields)

  result.add actions

  result.add foldObjectBody(target, typeDesc.name, fields)

  if defined(debug):
    echo fmt"startDes for `{$typeDesc.name}` type:"
    echo "------------------------"
    echo result.toStrLit
    echo "------------------------"

macro forDes*(key, value: untyped, target: typed, actions: untyped) =
  result = newStmtList()

  let
    typeDesc = target.getTypeDesc(Des)
    fields = typeDesc.fields(Des)

  result.add genForDes(key, value, fields, actions)
  result = newStmtList(newBlockStmt(ident("desLoop"), result))

  if defined(debug):
    echo fmt"forDes for `{$typeDesc.name}` type:"
    echo "------------------------"
    echo result.toStrLit
    echo "------------------------"
