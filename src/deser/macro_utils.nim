import std/[macros, options]

import pragmas

type
  Struct = object
    symType: NimNode
    fields: seq[Field]
  
  Field = object
    ident: NimNode
    symType: NimNode
    features: FieldFeatures

    case isCase: bool
    of true:
      branches: seq[FieldBranch]
    else:
      nil
  
  FieldFeatures = object
    skipped: bool
    skipSerializing: bool
    skipDeserializing: bool 
    inlineKeys: bool
    untagged: bool

    renameSerialize: Option[string]
    renameDeserialize: Option[string]
    skipSerializeIf: Option[NimNode]
    serializeWith: Option[NimNode]
  
  FieldBranchKind = enum
    Of
    Else
  
  FieldBranch = object
    case kind: FieldBranchKind
    of Of:
      condition: NimNode
    else:
      discard
    fields: seq[Field]
  
  ProcedureParams = object
    name: string
    public: bool
    lizerArgName: string

{.experimental: "strictFuncs".}
{.push compileTime, used.}
func fieldsFromRecList(recList: NimNode): seq[Field]

func renamedSerialize(self: Field): string =
  if self.features.renameSerialize.isSome:
    self.features.renameSerialize.unsafeGet()
  else:
    self.ident.strVal

func findPragma(pragmas: NimNode, pragmaSym: NimNode): Option[NimNode] =
  for p in pragmas:
    if p.kind in {nnkSym, nnkIdent} and eqIdent(p, pragmaSym):
      return some p
    if p.kind in {nnkExprColonExpr, nnkCall, nnkCallStrLit} and p.len > 0 and eqIdent(p[0], pragmaSym):
      return some p
  return none NimNode

func checkedStrValue(strLit: NimNode): string =
  expectKind strLit, nnkStrLit

  result = strLit.strVal

  if result.len == 0:
    error("Invalid value: string must be not empty", strLit)

func fieldFeaturesFromPragma(pragmas: NimNode): FieldFeatures =
  expectKind pragmas, nnkPragma

  # bool
  let
    skipped = pragmas.findPragma(bindSym("skipped"))
    skipSerializing = pragmas.findPragma(bindSym("skipSerializing"))
    skipDeserializing = pragmas.findPragma(bindSym("skipDeserializing"))
    inlineKeys = pragmas.findPragma(bindSym("inlineKeys"))
    untagged = pragmas.findPragma(bindSym("untagged"))

  # value
    renameSerialize = pragmas.findPragma(bindSym("renameSerialize"))
    renameDeserialize = pragmas.findPragma(bindSym("renameDeserialize"))
    skipSerializeIf = pragmas.findPragma(bindSym("skipSerializeIf"))
    serializeWith = pragmas.findPragma(bindSym("serializeWith"))
  
  result.skipped = skipped.isSome
  result.skipSerializing = skipSerializing.isSome
  result.skipDeserializing = skipDeserializing.isSome
  result.inlineKeys = inlineKeys.isSome
  result.untagged = untagged.isSome

  if renameSerialize.isSome:
    result.renameSerialize = some renameSerialize.unsafeGet()[1].checkedStrValue()
  
  if renameDeserialize.isSome:
    result.renameDeserialize = some renameDeserialize.unsafeGet()[1].checkedStrValue()
  
  if skipSerializeIf.isSome:
    result.skipSerializeIf = some skipSerializeIf.unsafeGet()[1]
  
  if serializeWith.isSome:
    result.serializeWith = some serializeWith.unsafeGet()[1]

func checkFeatures(field: Field) =
  if field.features.untagged and not field.isCase:
    error("The `untagged` pragma can only be used on the case field", field.ident)
  
func fieldFromIdentDefs(identDefs: NimNode, isCase = false): Field =
  expectKind identDefs, nnkIdentDefs
  expectKind identDefs[0], {nnkIdent, nnkPragmaExpr}

  # field without pragmas
  if identDefs[0].kind == nnkIdent:
    result = Field(
      ident: identDefs[0],
      symType: identDefs[1],
      isCase: isCase
    )
  # field with pragmas
  else:
    let pragmaExpr = identDefs[0]
    result = Field(
      ident: pragmaExpr[0],
      symType: identDefs[1],
      isCase: isCase,
      features: fieldFeaturesFromPragma(pragmaExpr[1])
    )
    checkFeatures(result)

func fieldBranchFromNimBranch(branch: NimNode): FieldBranch =
  expectKind branch, {nnkOfBranch, nnkElse}

  if branch.kind == nnkOfBranch:
    result = FieldBranch(kind: FieldBranchKind.Of)
    result.condition = branch[0]
    result.fields = fieldsFromRecList(branch[1])
  else:
    result = FieldBranch(kind: FieldBranchKind.Else)
    result.fields = fieldsFromRecList(branch[0])

func fieldFromRecCase(recCase: NimNode): Field =
  expectKind recCase, nnkRecCase

  result = fieldFromIdentDefs(recCase[0], isCase=true)

  for branch in recCase[1..^1]:
    result.branches.add fieldBranchFromNimBranch(branch)

func fieldsFromRecList(recList: NimNode): seq[Field] =
  expectKind recList, nnkRecList

  for rec in recList:
    case rec.kind
    of nnkIdentDefs:
      result.add fieldFromIdentDefs(rec)
    of nnkRecCase:
      result.add fieldFromRecCase(rec)
    of nnkNilLit:
      #[
      case kind: ...
      of ...:
        discard/nil
      ]#
      discard "do nothing"
    else:
      expectKind rec, {nnkIdentDefs, nnkRecCase, nnkNilLit}

func structFromTypeImpl(impl: NimNode): Struct =
  expectKind impl, nnkTypeDef
  expectKind impl[2], {nnkRefTy, nnkObjectTy}

  let objectTy = (
    if impl[2].kind == nnkObjectTy:
      impl[2]
    else:
      impl[2][0]
  )

  result.symType = impl[0]
  result.fields = fieldsFromRecList(objectTy[2])
  
func newProcDef(name: string, selfType: NimNode, lizerArgName: string, body: NimNode, public: bool): NimNode =
  #[
    proc name[T](self: selfType, lizerArgName: T) =
      body
  ]#
  let procName = (
    if public:
      nnkPostfix.newTree(
        newIdentNode("*"),
        newIdentNode(name)
      )
    else:
      newIdentNode(name)
  )
  nnkProcDef.newTree(
    procName,
    newEmptyNode(),
    nnkGenericParams.newTree(
      nnkIdentDefs.newTree(
        newIdentNode("T"),
        newEmptyNode(),
        newEmptyNode()
      )
    ),
    nnkFormalParams.newTree(
      newEmptyNode(),
      nnkIdentDefs.newTree(
        newIdentNode("self"),
        selfType,
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        newIdentNode(lizerArgName),
        nnkVarTy.newTree(newIdentNode("T")),
        newEmptyNode()
      )
    ),
    newEmptyNode(),
    newEmptyNode(),
    body
  )

func newProc(typeName: NimNode, params: ProcedureParams, body: varargs[NimNode]): NimNode =
  let body = newStmtList(
    body
  )
  result = newProcDef(params.name, typeName, params.lizerArgName, body, params.public)

func newPrefix(prefix: NimNode, body: NimNode): NimNode =
  result = nnkPrefix.newTree(prefix, body)

func newType(name: string, identDefs: varargs[NimNode]): NimNode =
  result = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      newIdentNode("SerializeWith"),
      newEmptyNode(),
      nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        nnkRecList.newTree(
          identDefs
        )
      )
    )
  )

func newBracketExpr(ident: NimNode): NimNode =
  result = nnkBracketExpr.newTree(ident)

func newPtr(ident: NimNode): NimNode =
  result = nnkPtrTy.newTree(ident)

func newBlockStmt(): NimNode =
  result = nnkBlockStmt.newTree()

func newTypeOf(ident: NimNode): NimNode =
  result = nnkTypeOfExpr.newTree(ident)

func newOfBranch(ident: NimNode, stmtList: NimNode): NimNode =
  result = nnkOfBranch.newTree(
    ident,
    stmtList
  )

func newElse(stmtList: NimNode): NimNode =
  result = nnkElse.newTree(stmtList)

func newDiscard(): NimNode =
  result = nnkDiscardStmt.newTree(newEmptyNode())

func newCaseStmt(ident: NimNode, branches: seq[NimNode]): NimNode =
  result = nnkCaseStmt.newTree(
    ident
  )
  for branch in branches:
    result.add branch
{.pop.}