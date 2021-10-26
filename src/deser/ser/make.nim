import std/[options, sequtils]

import flat, serialize_with
import ../pragmas
import ../utils

include ../macro_utils

{.experimental: "strictFuncs".}
{.push compileTime.}
func newProcMiddle(fields: seq[Field]): NimNode

func newSerializeWithType(field: Field): NimNode =
  # SerializeWith(serializeProc: withProc, value: self.fieldName)
  result = nnkObjConstr.newTree(
    nnkBracketExpr.newTree(
      bindSym("SerializeWith"),
      field.symType,
      newTypeOf(ident "state")
    ),
    nnkExprColonExpr.newTree(
      ident "serializeProc",
      field.features.serializeWith.get()
    ),
    nnkExprColonExpr.newTree(
      ident "value",
      newDotExpr(ident "self", field.ident)
    )
  )

func newFlatStructSerialize(item: NimNode): NimNode =
  # serialize(item, FlatMapSerializer(ser: state))
  let constrFlatMap = nnkObjConstr.newTree(
    nnkBracketExpr.newTree(
      bindSym("FlatMapSerializer"),
      
      newTypeOf(ident "state")
    ),
    nnkExprColonExpr.newTree(
      ident "ser",
      newCall(bindSym("addr"), ident "state")
    )
  )
  let flatState = newVarStmt(ident "flatState", constrFlatMap)
  result = newStmtList(
    flatState,
    newCall("serialize", item, ident "flatState")
  )

func newSerializeItem(field: Field): NimNode =
  if field.features.serializeWith.isSome:
    result = newSerializeWithType(field)
  else:
    result = newDotExpr(ident "self", field.ident)

func newUncheckedSerializeField(field: Field): NimNode =
  if field.features.inlineKeys:
    result = newFlatStructSerialize(newSerializeItem(field))
  else:
    result = newCall(
      "serializeStructField",
      ident "state",
      newLit field.renamedSerialize,
      newSerializeItem(field)
    )

func newSerializeCheck(field: Field, happyPathBody: NimNode): NimNode =
  if field.features.skipSerializeIf.isSome:
    let
      skipIfProc = field.features.skipSerializeIf.unsafeGet
      callSkipIfProc = newCall(skipIfProc, newDotExpr(ident "self", field.ident))
      condition = newPrefix(ident "not", callSkipIfProc)
    #[
    if not skipIfProc(self.fieldName):
      happyPathBody
    ]#
    result = newIfStmt((condition, happyPathBody))
  else:
    result = happyPathBody
  

func newSerializeField(field: Field): NimNode =
  let serialize = newUncheckedSerializeField(field)
  result = newSerializeCheck(field, serialize)

func newSerializeCaseField(field: Field): NimNode =
  var branches: seq[NimNode] = @[]
  for branch in field.branches:
    var tempStmt = (
      #[
      case kind: ...
      of ...:
        discard/nil
      ]#
      if branch.fields.len == 0:
        newDiscard()
      else:
        newProcMiddle(branch.fields)
    )
    if branch.kind == FieldBranchKind.Of:
      branches.add newOfBranch(branch.condition, tempStmt)
    else:
      branches.add newElse(tempStmt)
  
  let
    # serialize case ("kind") field without `skipSerializeIf` check
    serializeCaseField = (
      # do nothing if the `untagged` pragma is detected
      if field.features.untagged:
        newEmptyNode()
      else:
        newUncheckedSerializeField(field)
    )
    # serialize fields inside branches
    serializeBranchesFields = newCaseStmt(newDotExpr(ident "self", field.ident), branches)
    #[
    `serializeCaseField` body
    `serializeBranchesFields` body
    ]#
  
  let serialize = newStmtList(serializeCaseField, serializeBranchesFields)
  
  # add `skipSerializeIf` check
  result = newSerializeCheck(field, serialize)
  
func newProcStart(lizerProcName, lizerArgName, typeName: string): NimNode =
  # asAddr(state, lizerProcName(lizerArgName, "typeName"))
  let callLizerProc = nnkCall.newTree(
    newIdentNode(lizerProcName),
    newIdentNode(lizerArgName),
    newLit(typeName)
  )
  result = newCall(bindSym("asAddr"), ident "state", callLizerProc)

func newProcMiddle(fields: seq[Field]): NimNode =
  result = newStmtList()
  for field in fields.filterIt(not (it.features.skipSerializing or it.features.skipped)):
    if field.isCase:
      result.add newSerializeCaseField(field)
    else:
      result.add newSerializeField(field)

func newProcEnd(): NimNode =
  # endStruct(state)
  result = newCall(
    "endStruct",
    ident "state"
  )

macro makeSerializable*(T: typedesc, public: static[bool] = false) =
  ##[
Generates `serialize` for your type. Supports only `object` and `ref`.
All tuples implement `serialize` out of the box.
  ]##
  let struct = structFromTypeImpl(T.getTypeImpl[1].getImpl)
  let procParams = ProcedureParams(
    name: "serialize",
    public: public,
    lizerArgName: "serializer",
  )
  result = newProc(struct.symType, procParams, [
    newProcStart("serializeStruct", procParams.lizerArgName, struct.symType.strVal),
    newProcMiddle(struct.fields),
    newProcEnd()
  ])

{.pop.}