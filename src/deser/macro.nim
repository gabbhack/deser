{.experimental: "strictFuncs".}
import std/[macros, options, sugar]

import pragmas

template suka() {.pragma.}

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
    id {.suka, suka.}: int
    lol: string

    case kind: bool
    of true:
      a: int
    else:
      b: int
  
  Alias = Test

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


func by(T: typedesc[FieldFeatures], pragma: NimNode): T =
  expectKind pragma, nnkPragma
  # TODO
  discard


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
  result = Struct(sym: objectTy.sym, isRef: objectTy.isRef)

  let recList = objectTy.node[2]
  result.fields = seq[Field].by(recList=recList)


proc explore(node: NimNode) =
  let objectTy = ObjectTy.by(sym=node)
  echo objectTy.node.treeRepr


macro run(typ: typed{`type`}) =
  explore typ

run Alias
