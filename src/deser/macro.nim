{.experimental: "strictFuncs".}
import std/[macros, options, tables]

import pragmas

template suka() {.pragma.}

template suka1(a: int, b: string) {.pragma.}

type
  ObjectTy = object
    isRef: bool
    sym: NimNode
    node: NimNode

  Struct = object
    isRef: bool
    sym: NimNode
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

  Test = object
    id {.suka1(1, "123").}: int
    lol: string

    case kind: bool
    of false..true:
      a: int
  
  Alias = Test

# forward decl
func by(T: typedesc[seq[Field]], recList: NimNode): T

proc fill(self: var FieldFeatures, sym: NimNode, values: seq[NimNode] = @[]) =
  self.untagged = sym == bindSym("untagged")
  self.skipped = sym == bindSym("skipped")
  self.skipSerializing = sym == bindSym("skipSerializing")
  self.skipDeserializing = sym == bindSym("skipDeserializing")
  self.inlineKeys = sym == bindSym("inlineKeys")

  if sym == bindSym("serializeWith"):
    self.serializeWith = some values[0]
  elif sym == bindSym("renameSerialize"):
    self.renameSerialize = some values[0].strVal
  elif sym == bindSym("renameDeserialize"):
    self.renameDeserialize = some values[0].strVal
  elif sym == bindSym("skipSerializeIf"):
    self.skipSerializeIf = some values[0]

func by(T: typedesc[ObjectTy], sym: NimNode): T =
  expectKind sym, nnkSym

  let typeDef = sym.getImpl
  debugEcho typeDef.treeRepr
  expectKind typeDef, nnkTypeDef

  let typeImpl = typeDef[2]

  case typeImpl.kind
  of nnkSym:
    # For alias types
    # e.g. type Foo = Bar
    result = by(T, typeImpl)
  of nnkRefTy:
    result = ObjectTy(isRef: true, sym: sym, node: typeImpl[0])
  of nnkObjectTy:
    result = ObjectTy(isRef: false, sym: sym, node: typeImpl)
  else:
    expectKind typeImpl, {nnkSym, nnkRefTy, nnkObjectTy}


func by(T: typedesc[FieldFeatures], pragmas: NimNode): T =
  expectKind pragmas, nnkPragma
  
  for pragma in pragmas:
    case pragma.kind
    of nnkSym:
      let sym = pragma
      result.fill(sym)
    of nnkCall:
      # For {. pragmaName(something) .}
      let
        sym = pragma[0]
        values = if pragma.len > 1: pragma[1..pragma.len-1] else: @[]
      result.fill(sym, values)
    else:
      expectKind pragma, {nnkSym, nnkCall}


func by(T: typedesc[Field], identDefs: NimNode): T =
  expectKind identDefs, nnkIdentDefs

  let
    identNode = identDefs[0]
    sym = identDefs[1]
  expectKind sym, nnkSym

  case identNode.kind
  of nnkIdent:
    result = Field(ident: identNode, symType: sym)
  of nnkPragmaExpr:
    result = Field(ident: identNode[0], symType: sym)
    result.features = FieldFeatures.by(pragmas=identNode[1])
  else:
    expectKind identNode, {nnkIdent, nnkPragmaExpr}


func by(T: typedesc[Field], recCase: NimNode): T =
  expectKind recCase, nnkRecCase

  let identDefs = recCase[0]
  var field = Field.by(identDefs=identDefs)
  field.isCase = true

  let branches = recCase[1..recCase.len-1]

  for branch in branches:
    case branch.kind
    of nnkOfBranch:
      let
        # TODO condition must contain all nodes from nnkOfBranch before nnkRecList
        condition = copy branch
        recList = branch[1]
        fields = seq[Field].by(recList=recList)

      field.branches.add FieldBranch(
        kind: Of,
        condition: condition,
        fields: fields
      )
    of nnkElse:
      let
        recList = branch[0]
        fields = seq[Field].by(recList=recList)
      
      field.branches.add FieldBranch(
        kind: Else,
        fields: fields
      )
    else:
      expectKind branch, {nnkOfBranch, nnkElse}


func by(T: typedesc[seq[Field]], recList: NimNode): T =
  expectKind recList, nnkRecList

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
  result = Struct(
    sym: objectTy.sym,
    isRef: objectTy.isRef,
    fields: seq[Field].by(recList=recList)
  )


proc explore(node: NimNode) =
  let objectTy = ObjectTy.by(sym=node)
  discard Struct.by objectTy
  echo objectTy.node.treeRepr


macro run(typ: typed{`type`}) =
  explore typ

run Alias
