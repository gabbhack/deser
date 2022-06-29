{.experimental: "strictFuncs".}
import std/[macros, options, tables]

import ../pragmas


type
  ObjectTy = object
    isRef*: bool
    sym*: NimNode
    node*: NimNode

  Struct = object
    isRef*: bool
    sym*: NimNode
    fields*: seq[Field]
  
  Field = object
    ident*: NimNode
    typ*: NimNode
    features*: FieldFeatures

    case isCase*: bool
    of true:
      branches*: seq[FieldBranch]
    else:
      nil
  
  FieldFeatures = object
    skipSerializing*: bool
    skipDeserializing*: bool 
    inlineKeys*: bool
    untagged*: bool

    renameSerialize*: Option[string]
    renameDeserialize*: Option[string]
    skipSerializeIf*: Option[NimNode]
    serializeWith*: Option[NimNode]
  
  FieldBranchKind = enum
    Of
    Else

  FieldBranch = object
    case kind*: FieldBranchKind
    of Of:
      condition*: NimNode
    else:
      discard
    fields*: seq[Field]
  
  Key = object
    enumSym*: NimNode
    varIdent*: NimNode
    varType*: NimNode
    features*: FieldFeatures
  
  KeyStruct {.used.} = object
    enumSym*: NimNode
    fields*: seq[Key]
    unknownKeyEnumSym*: NimNode


{.push used.}
func isSkipSerializing(self: Field | Key): bool = self.features.skipSerializing

func isSkipDeserializing(self: Field | Key): bool = self.features.skipDeserializing

func isUntagged(self: Field | Key): bool = self.features.untagged

func getSkipSerializeIf(self: Field | Key): Option[NimNode] = self.features.skipSerializeIf

func getSerializeWith(self: Field | Key): Option[NimNode] = self.features.serializeWith

func serializeName(self: Field | Key): string =
  if self.features.renameSerialize.isSome:
    self.features.renameSerialize.unsafeGet
  else:
    when self is Key:
      self.varIdent.strVal
    else:
      self.ident.strVal


func deserializeName(self: Field | Key): string =
  if self.features.renameDeserialize.isSome:
    self.features.renameDeserialize.unsafeGet
  else:
    when self is Key:
      self.varIdent.strVal
    else:
      self.ident.strVal


# forward decl
func by(T: typedesc[seq[Field]], recList: NimNode): T


func asKeys(fields: seq[Field]): seq[Key] =
  result = newSeqOfCap[Key](fields.len)

  for field in fields:
    if not field.isSkipDeserializing:
      result.add Key(
        enumSym: genSym(nskEnumField, field.ident.strVal),
        varIdent: field.ident,
        varType: field.typ,
        features: field.features
      )

      if field.isCase:
        for branch in field.branches:
          result.add branch.fields.asKeys


func copyWithoutChild(copyOf: NimNode, idx = 0, n = 1): NimNode =
  result = copy copyOf
  result.del idx, n


proc fill(self: var FieldFeatures, sym: NimNode, values: seq[NimNode] = @[]) =
  if sym == bindSym("untagged"):
    self.untagged = true
  elif sym == bindSym("skipped"):
    self.skipDeserializing = true
    self.skipSerializing = true
  elif sym == bindSym("skipSerializing"):
    self.skipSerializing = true
  elif sym == bindSym("skipDeserializing"):
    self.skipDeserializing = true
  elif sym == bindSym("serializeWith"):
    self.serializeWith = some values[0]
  elif sym == bindSym("renamed"):
    self.renameDeserialize = some values[0].strVal
    self.renameSerialize = some values[0].strVal
  elif sym == bindSym("renameSerialize"):
    self.renameSerialize = some values[0].strVal
  elif sym == bindSym("renameDeserialize"):
    self.renameDeserialize = some values[0].strVal
  elif sym == bindSym("skipSerializeIf"):
    self.skipSerializeIf = some values[0]


func by(T: typedesc[ObjectTy], sym: NimNode): T =
  # Get temp `ObjectTy` from symbol of type
  expectKind sym, nnkSym

  let typeDef = sym.getImpl

  if defined(debugObjectTy):
    debugEcho typeDef.treeRepr

  expectKind typeDef, nnkTypeDef

  let typeImpl = typeDef[2]

  case typeImpl.kind
  of nnkSym:
    # For alias types
    # e.g. type Foo = Bar
    # recursively calling ourselves
    result = ObjectTy.by typeImpl
  of nnkRefTy:
    case typeImpl[0].kind
    of nnkSym:
      # For type Foo = ref Bar
      var objectTy = ObjectTy.by typeImpl[0]
      # use alias type
      objectTy.sym = sym
      # hack to bypass strictFunc
      result = objectTy
    of nnkObjectTy:
      # # For type Foo = ref object
      result = ObjectTy(isRef: true, sym: sym, node: typeImpl[0])
    else:
      expectKind typeImpl[0], {nnkSym, nnkObjectTy}
  of nnkObjectTy:
    # # For type Foo = object
    result = ObjectTy(isRef: false, sym: sym, node: typeImpl)
  else:
    expectKind typeImpl, {nnkSym, nnkRefTy, nnkObjectTy}


func by(T: typedesc[FieldFeatures], pragmas: NimNode): T =
  # Check whether the field contains our pragmas
  expectKind pragmas, nnkPragma
  
  for pragma in pragmas:
    case pragma.kind
    of nnkSym:
      # {.pragmaName.}
      let sym = pragma
      result.fill(sym)
    of nnkCall:
      # {.pragmaName(values).}
      let
        sym = pragma[0]
        values = if pragma.len > 1: pragma[1..pragma.len-1] else: @[]
      result.fill(sym, values)
    else:
      expectKind pragma, {nnkSym, nnkCall}


func by(T: typedesc[Field], identDefs: NimNode): T =
  # Get field from usual statement
  expectKind identDefs, nnkIdentDefs

  let identNode = identDefs[0]

  case identNode.kind
  of nnkIdent:
    result = Field(ident: identNode, typ: identDefs[1])
  of nnkPragmaExpr:
    result = Field(ident: identNode[0], typ: identDefs[1])
    result.features = FieldFeatures.by(pragmas=identNode[1])
  else:
    expectKind identNode, {nnkIdent, nnkPragmaExpr}


func by(T: typedesc[Field], recCase: NimNode): T =
  # Get field from case statement
  expectKind recCase, nnkRecCase

  let identDefs = recCase[0]
  result = Field.by(identDefs=identDefs)
  result.isCase = true

  let branches = recCase[1..recCase.len-1]

  for branch in branches:
    case branch.kind
    of nnkOfBranch:
      let
        # for future code generation
        # we need to safe ofBranch without body
        condition = branch.copyWithoutChild(branch.len-1)
        recList = branch[branch.len-1]
        fields = seq[Field].by(recList=recList)

      result.branches.add FieldBranch(
        kind: Of,
        condition: condition,
        fields: fields
      )
    of nnkElse:
      let
        recList = branch[0]
        fields = seq[Field].by(recList=recList)
      
      result.branches.add FieldBranch(
        kind: Else,
        fields: fields
      )
    else:
      expectKind branch, {nnkOfBranch, nnkElse}


func by(T: typedesc[seq[Field]], recList: NimNode): T =
  expectKind recList, {nnkRecList, nnkEmpty}

  if recList.kind != nnkEmpty:
    for fieldNode in recList:
      case fieldNode.kind
      of nnkIdentDefs:
        result.add Field.by(identDefs=fieldNode)
      of nnkRecCase:
        result.add Field.by(recCase=fieldNode)
      of nnkNilLit:
        # of/else:
        #   nil
        discard
      else:
        expectKind fieldNode, {nnkIdentDefs, nnkRecCase}


func by(T: typedesc[Struct], objectTy: ObjectTy): T =
  let recList = objectTy.node[2]

  Struct(
    sym: objectTy.sym,
    isRef: objectTy.isRef,
    fields: seq[Field].by(recList=recList)
  )


func newExportedIdent(name: string): NimNode =
  nnkPostfix.newTree(
    newIdentNode("*"),
    ident name
  )


func parse(node: NimNode): Struct =
  let objectTy = ObjectTy.by(sym=node)

  Struct.by objectTy

{.pop.}
