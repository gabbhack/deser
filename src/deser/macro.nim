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

  Test = ref object
    id {.suka1(1, "123").}: int
    lol: string

    case kind: bool
    of true:
      a: int
    else:
      b: int
  
  Alias = Test

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
      let sym = pragma[0]
      let values = if pragma.len > 1: pragma[1..pragma.len-1] else: @[]
      result.fill(sym, values)
    else:
      expectKind pragma, {nnkSym, nnkCall}


func by(T: typedesc[Field], identDefs: NimNode): T =
  expectKind identDefs, nnkIdentDefs

  let identNode = identDefs[0]
  let sym = identDefs[1]
  expectKind sym, nnkSym

  case identNode.kind
  of nnkIdent:
    result = Field(ident: identNode, symType: sym)
  of nnkPragmaExpr:
    result = Field(ident: identNode[0], symType: sym)
    result.features = FieldFeatures.by identNode[1]
  else:
    expectKind identNode, {nnkIdent, nnkPragmaExpr}


func by(T: typedesc[seq[Field]], recList: NimNode): T =
  expectKind recList, nnkRecList

  for fieldNode in recList:
    case fieldNode.kind
    of nnkIdentDefs:
      result.add Field.by(identDefs=fieldNode)
    of nnkRecCase:
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
