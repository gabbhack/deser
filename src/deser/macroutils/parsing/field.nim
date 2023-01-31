discard """
  action: "compile"
"""
import std/[
  macros,
  options
]

from deser/macroutils/types import
  Field,
  initField,

  FieldFeatures,
  initFieldFeatures,
  initEmptyFieldFeatures,

  FieldBranch,
  initFieldBranch,

  FieldBranchKind,
  FieldFeatures,
  TypeInfo,

  recList,
  merge

from pragmas as parse_pragmas import
  parsePragma

from deser/pragmas import
  untagged,
  skipped,
  skipSerializing,
  skipDeserializing,
  serializeWith,
  deserializeWith,
  renamed,
  renameSerialize,
  renameDeserialize,
  skipSerializeIf,
  defaultValue,
  aliases

# for pattern matching and assertKind
import deser/macroutils/matching

# Forward declaration
func fieldsFromRecList*(recList: NimNode): seq[Field]

func fromIdentDefs*(fieldTy: typedesc[Field], identDefs: NimNode): Field

func fromRecCase*(fieldTy: typedesc[Field], recCase: NimNode): Field

func fromPragma*(featuresTy: typedesc[FieldFeatures], pragma: Option[NimNode]): FieldFeatures

func fromBranch*(branchTy: typedesc[FieldBranch], branch: NimNode): seq[FieldBranch]

func getType(identDefs: NimNode): NimNode

func getNameIdent(identDefs: NimNode): NimNode

func getPragma(identDefs: NimNode): Option[NimNode]

func isPublic(identDefs: NimNode): bool

func deSymBracketExpr(bracket: NimNode): NimNode


# Parse
func parseFields*(typeInfo: TypeInfo): seq[Field] =
  ## Parse fields from a typeInfo
  if Some(@reclist) ?= typeInfo.recList:
    fieldsFromRecList(recList)
  else:
    newSeqOfCap[Field](0)

func fieldsFromRecList*(recList: NimNode): seq[Field] =
  ## Parse fields from a recList
  var firstCaseField = none Field

  for fieldNode in recList:
    case fieldNode.kind
    of nnkIdentDefs:
      # usual field
      result.add Field.fromIdentDefs(fieldNode)
    of nnkRecCase:
      # case field
      let field = Field.fromRecCase(fieldNode)
      if firstCaseField.isNone:
        firstCaseField = some field
      else:
        # Merge all cases from this level into first case field.
        #[
        Example:
        type Test = object
          case firstKind: FirstKind
          of Foo:
            discard
          of Bar:
            discard
          
          case secondKind: SecondKind
          of Fizz:
            discard
          of Bazz:
            discard
        
        In our internal representation it will have the form:
        type Test = object
          case firstKind: FirstKind
          of Foo:
            case secondKind: SecondKind
            of Fizz:
              discard
            of Bazz:
              discard
          of Bar:
            case secondKind: SecondKind
            of Fizz:
              discard
            of Bazz:
              discard
        ]#
        # This transformation makes it easier to generate deserialization code.
        firstCaseField.get().merge(field)
    of nnkNilLit:
      # empty field: discard/nil
      discard
    else:
      assertKind fieldNode, {nnkIdentDefs, nnkRecCase, nnkNilLit}

  if firstCaseField.isSome:
    result.add firstCaseField.get()

func fromIdentDefs*(fieldTy: typedesc[Field], identDefs: NimNode): Field =
  ## Parse a field from an identDefs node
  assertKind identDefs, {nnkIdentDefs}

  initField(
    nameIdent=getNameIdent(identDefs),
    typeNode=getType(identDefs),
    features=FieldFeatures.fromPragma(getPragma(identDefs)),
    public=isPublic(identDefs),
    isCase=false,
    branches=newSeqOfCap[FieldBranch](0)
  )

func fromRecCase*(fieldTy: typedesc[Field], recCase: NimNode): Field =
  ## Parse a field from a recCase node
  assertKind recCase, {nnkRecCase}
  assertMatch recCase:
    RecCase[@identDefs, all @rawBranches]

  var branches = newSeqOfCap[FieldBranch](recCase.len-1)

  for branch in rawBranches:
    {.warning[UnsafeSetLen]: off.}
    branches.add FieldBranch.fromBranch(branch)
    {.warning[UnsafeSetLen]: on.}

  initField(
    nameIdent=getNameIdent(identDefs),
    typeNode=getType(identDefs),
    features=FieldFeatures.fromPragma(getPragma(identDefs)),
    public=isPublic(identDefs),
    isCase=true,
    branches=branches
  )

func fromBranch*(branchTy: typedesc[FieldBranch], branch: NimNode): seq[FieldBranch] =
  ## Parse a field branch from a branch node

  assertMatch branch:
    OfBranch[until @condition is RecList(), @recList] |
    Else[@recList]

  let fields = fieldsFromRecList(recList)

  if condition.len > 0:
    result = newSeqOfCap[FieldBranch](condition.len)
    for cond in condition:
      result.add initFieldBranch(
        fields=fields,
        conditionOfBranch=some nnkOfBranch.newTree(cond)
      )
  else:
    result.add initFieldBranch(
      fields=fields,
      conditionOfBranch=none NimNode
    )

func fromPragma*(featuresTy: typedesc[FieldFeatures], pragma: Option[NimNode]): FieldFeatures =
  ## Parse features from a pragma

  if Some(@pragma) ?= pragma:
    assertKind pragma, {nnkPragma}

    let 
      untaggedSym = bindSym("untagged")
      skippedSym = bindSym("skipped")
      skipSerializingSym = bindSym("skipSerializing")
      skipDeserializingSym = bindSym("skipDeserializing")
      serializeWithSym = bindSym("serializeWith")
      deserializeWithSym = bindSym("deserializeWith")
      renamedSym = bindSym("renamed")
      renameSerializeSym = bindSym("renameSerialize")
      renameDeserializeSym = bindSym("renameDeserialize")
      skipSerializeIfSym = bindSym("skipSerializeIf")
      defaultValueSym = bindSym("defaultValue")
      aliasesSym = bindSym("aliases")

    var
      untagged = false
      skipSerializing = false
      skipDeserializing = false
      serializeWith = none NimNode
      deserializeWith = none NimNode
      renameDeserialize = none NimNode
      renameSerialize = none NimNode
      skipSerializeIf = none NimNode
      defaultValue = none NimNode
      aliases = newSeqOfCap[NimNode](0)

    for symbol, values in parsePragma(pragma):
      if symbol == untaggedSym:
        untagged = true
      elif symbol == skippedSym:
        skipDeserializing = true
        skipSerializing = true
      elif symbol == skipSerializingSym:
        skipSerializing = true
      elif symbol == skipDeserializingSym:
        skipDeserializing = true
      elif symbol == serializeWithSym:
        serializeWith = some values[0]
      elif symbol == deserializeWithSym:
        deserializeWith = some values[0]
      elif symbol == renamedSym:
        renameDeserialize = some values[0]
        renameSerialize = some values[0]
      elif symbol == renameSerializeSym:
        renameSerialize = some values[0]
      elif symbol == renameDeserializeSym:
        renameDeserialize = some values[0]
      elif symbol == skipSerializeIfSym:
        skipSerializeIf = some values[0]
      elif symbol == defaultValueSym:
        if values[0].kind == nnkNilLit:
          defaultValue = some newEmptyNode()
        else:
          defaultValue = some values[0]
      elif symbol == aliasesSym:
        assertKind values[0], {nnkHiddenStdConv}
        assertMatch values[0]:
          HiddenStdConv[Empty(), Bracket[all @values]]
        aliases = values

    if aliases.len > 0 and renameDeserialize.isSome:
      error("Cannot use both `aliases` and `renameDeserialize` on the same field.", pragma)

    result = initFieldFeatures(
      skipSerializing = skipSerializing,
      skipDeserializing = skipDeserializing,
      untagged = untagged,
      renameSerialize = renameSerialize,
      renameDeserialize = renameDeserialize,
      skipSerializeIf = skipSerializeIf,
      serializeWith = serializeWith,
      deserializeWith = deserializeWith,
      defaultValue = defaultValue,
      aliases = aliases
    )
  else:
    result = initEmptyFieldFeatures()

func getType(identDefs: NimNode): NimNode =
  ## Get the type of the field from an identDefs node

  assertMatch identDefs:
    IdentDefs[_, @typeNode, _]

  case typeNode.kind
  # generic
  of nnkBracketExpr:
    deSymBracketExpr(typeNode)
  else:
    typeNode

func getNameIdent(identDefs: NimNode): NimNode =
  ## Get the name of the field from an identDefs node

  assertMatch identDefs:
    IdentDefs[
      PostFix[_, @name is Ident()] |
      (@name is Ident()) |
      PragmaExpr[
        Postfix[_, @name is Ident()] | 
        (@name is Ident()),
        _
      ],
      _,
      _
    ]
  
  name

func getPragma(identDefs: NimNode): Option[NimNode] =
  ## Get the pragma from an identDefs
  
  assertMatch identDefs:
    IdentDefs[
      (
        PragmaExpr[_, @pragma is Pragma()] |
        Ident() |
        PostFix[_, Ident()]
      ),
      _,
      _
    ]
  
  pragma

func isPublic(identDefs: NimNode): bool =
  ## Check if the field is public

  assertMatch identDefs:
    IdentDefs[
      (@public is PostFix()) |
      Ident() |
      PragmaExpr[
        (@public is PostFix()) | 
        Ident(),
        _
      ],
      _,
      _
    ]

  public.isSome

func deSymBracketExpr(bracket: NimNode): NimNode =
  ## HACK: https://github.com/nim-lang/Nim/issues/19670
  assertKind bracket, {nnkBracketExpr}

  result = nnkBracketExpr.newTree(bracket[0])

  for i in bracket[1..bracket.len-1]:
    case i.kind
    of nnkSym:
      result.add i.strVal.ident
    of nnkBracketExpr:
      result.add deSymBracketExpr(i)
    else:
      result.add i


when isMainModule:
  type Test[T] = object

  macro run() =
    block:
      let identDefs = nnkIdentDefs.newTree(
        newIdentNode("id"),
        newIdentNode("int"),
        newEmptyNode()
      )

      doAssert identDefs.getPragma().isNone
    
    block:
      let identDefs = nnkIdentDefs.newTree(
        nnkPragmaExpr.newTree(
          newIdentNode("id"),
          nnkPragma.newTree(
            newIdentNode("test")
          )
        ),
        newIdentNode("int"),
        newEmptyNode()
      )

      doAssert identDefs.getPragma().get() == nnkPragma.newTree(newIdentNode("test"))

    block:
      doAssertRaises(AssertionDefect):
        discard getPragma(newEmptyNode())
    
    block:
      let identDefs = [
        nnkIdentDefs.newTree(
          newIdentNode("id"),
          newIdentNode("int"),
          newEmptyNode()
        ),
        nnkIdentDefs.newTree(
          nnkPostfix.newTree(
            newIdentNode("*"),
            newIdentNode("id")
          ),
          newIdentNode("int"),
          newEmptyNode()
        ),
        nnkIdentDefs.newTree(
          nnkPragmaExpr.newTree(
            newIdentNode("id"),
            nnkPragma.newTree(
              newIdentNode("test")
            )
          ),
          newIdentNode("int"),
          newEmptyNode()
        ),
        nnkIdentDefs.newTree(
          nnkPragmaExpr.newTree(
            nnkPostfix.newTree(
              newIdentNode("*"),
              newIdentNode("id")
            ),
            nnkPragma.newTree(
              newIdentNode("test")
            )
          ),
          newIdentNode("int"),
          newEmptyNode()
        )
      ]

      for i in identDefs:
        doAssert getNameIdent(i) == ident "id"
    
    block:
      let 
        withGeneric = nnkIdentDefs.newTree(
          newIdentNode("id"),
          nnkBracketExpr.newTree(
            bindSym("Test"),
            newIdentNode("T")
          ),
          newEmptyNode()
        )
        withoutGeneric = nnkIdentDefs.newTree(
          newIdentNode("id"),
          bindSym("int"),
          newEmptyNode()
        )
      
      doAssert withGeneric.getType() == nnkBracketExpr.newTree(
        bindSym("Test"),
        newIdentNode("T")
      )

      doAssert withoutGeneric.getType() == bindSym("int")

  run()
