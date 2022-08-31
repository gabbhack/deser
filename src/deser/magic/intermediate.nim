import std/[
  macros,
  options,
  tables
]

import ../pragmas


type
  Struct = object of RootObj
    isRef*: bool
    isDistinct*: bool
    sym*: NimNode
    fields*: seq[Field]
    enumSym*: NimNode
    enumUnknownFieldSym*: NimNode
    features*: StructFeatures
    genericParams*: Option[NimNode]
    flattenFields*: seq[Field]

  StructFeatures = object
    onUnknownKeysValue*: Option[NimNode]
  
  Field = object
    ident*: NimNode
    typ*: NimNode
    enumFieldSym*: NimNode
    features*: FieldFeatures
    deserializeWithType*: Option[NimNode]
    serializeWithType*: Option[NimNode]

    case isCase*: bool
    of true:
      branches*: seq[FieldBranch]
    else:
      discard
  
  FieldFeatures = object
    skipSerializing*: bool
    skipDeserializing*: bool 
    inlineKeys*: bool
    untagged*: bool

    renameSerialize*: Option[string]
    renameDeserialize*: Option[string]
    skipSerializeIf*: Option[NimNode]
    serializeWith*: Option[NimNode]
    deserializeWith*: Option[NimNode]
    defaultValue*: Option[NimNode]
  
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


{.push used.}
proc getFields(recList: NimNode): seq[Field]

proc getOnUnknownKeysValue(self: Struct): Option[NimNode] = self.features.onUnknownKeysValue

proc isSkipSerializing(self: Field): bool = self.features.skipSerializing

proc isSkipDeserializing(self: Field): bool = self.features.skipDeserializing

proc isUntagged(self: Field): bool = self.features.untagged

proc getSkipSerializeIf(self: Field): Option[NimNode] = self.features.skipSerializeIf

proc getSerializeWith(self: Field): Option[NimNode] = self.features.serializeWith

proc getDeserializeWith(self: Field): Option[NimNode] = self.features.deserializeWith

proc getDefaultValue(self: Field): Option[NimNode] = self.features.defaultValue

proc serializeName(self: Field): string =
  if self.features.renameSerialize.isSome:
    self.features.renameSerialize.unsafeGet
  else:
    self.ident.strVal


proc deserializeName(self: Field): string =
  if self.features.renameDeserialize.isSome:
    self.features.renameDeserialize.unsafeGet
  else:
    self.ident.strVal
  

proc flatten(fields: seq[Field]): seq[Field] =
  result = newSeqOfCap[Field](fields.len)

  for field in fields:
    if not field.isSkipDeserializing:
      if not field.isCase or (field.isCase and not field.isUntagged):
        result.add field
      if field.isCase:
        for branch in field.branches:
          result.add branch.fields.flatten


proc copyWithoutChild(copyOf: NimNode, idx = 0, n = 1): NimNode =
  result = copy copyOf
  result.del idx, n


proc fill(self: var StructFeatures, sym: NimNode, values: seq[NimNode] = @[]) =
  if sym == bindSym("onUnknownKeys"):
    self.onUnknownKeysValue = some values[0]


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
  elif sym == bindSym("deserializeWith"):
    self.deserializeWith = some values[0]
  elif sym == bindSym("renamed"):
    self.renameDeserialize = some values[0].strVal
    self.renameSerialize = some values[0].strVal
  elif sym == bindSym("renameSerialize"):
    self.renameSerialize = some values[0].strVal
  elif sym == bindSym("renameDeserialize"):
    self.renameDeserialize = some values[0].strVal
  elif sym == bindSym("skipSerializeIf"):
    self.skipSerializeIf = some values[0]
  elif sym == bindSym("defaultValue"):
    if values[0].kind == nnkNilLit:
      self.defaultValue = some newEmptyNode()
    else:
      self.defaultValue = some values[0]


proc fill(self: var (FieldFeatures | StructFeatures), pragmas: NimNode) =
  # Check whether the field or object contains our pragmas
  expectKind pragmas, {nnkPragma, nnkPragmaExpr}

  let pragmas =
    if pragmas.kind == nnkPragma:
      # for field
      pragmas
    else:
      # for object
      pragmas[1]

  for pragma in pragmas:
    case pragma.kind
    of nnkSym:
      # {.pragmaName.}
      let sym = pragma
      self.fill(sym)
    of nnkCall, nnkExprColonExpr:
      # {.pragmaName(values).}
      # or
      # {.pragmaName: value.}
      let
        sym = pragma[0]
        values = if pragma.len > 1: pragma[1..pragma.len-1] else: @[]
      self.fill(sym, values)
    of nnkIdent:
      discard "process only typed nodes"
    else:
      expectKind pragma, {nnkSym, nnkCall, nnkExprColonExpr, nnkIdent}

  when typeof(self) is FieldFeatures:
    if self.skipSerializing and self.serializeWith.isSome:
      warning "`serializeWith` does not working with `skipSerializing`", pragmas
    
    if self.skipDeserializing and self.deserializeWith.isSome:
      warning "`deserializeWith` does not working with `skipDeserializing`", pragmas


proc deSymBracketExpr(bracket: NimNode): NimNode =
  # HACK: https://github.com/nim-lang/Nim/issues/19670
  expectKind bracket, nnkBracketExpr

  result = nnkBracketExpr.newTree(bracket[0])

  for i in bracket[1..bracket.len-1]:
    case i.kind
    of nnkSym:
      result.add i.strVal.ident
    of nnkBracketExpr:
      result.add deSymBracketExpr(i)
    else:
      result.add i


proc init(Self: typedesc[Field], identDefs: NimNode, isCase: bool): Self =
  # Get field from usual statement
  expectKind identDefs, nnkIdentDefs

  let
    identNode = identDefs[0]
    typeNode = identDefs[1]
    typ = (
      case typeNode.kind
      of nnkSym:
        typeNode
      of nnkBracketExpr:
        deSymBracketExpr(typeNode)
      else:
        typeNode
    )

  case identNode.kind
  of nnkIdent:
    result = Self(
      ident: identNode,
      typ: typ,
      enumFieldSym: genSym(nskEnumField, identNode.strVal),
    )
  of nnkPragmaExpr:
    result = Self(
      ident: identNode[0],
      typ: typ,
      enumFieldSym: genSym(nskEnumField, identNode[0].strVal)
    )
    result.features.fill(pragmas=identNode[1])

    if result.features.deserializeWith.isSome:
      result.deserializeWithType = some genSym(nskType, "DeserializeWith")
    
    if result.features.serializeWith.isSome:
      result.serializeWithType = some genSym(nskType, "SerializeWith")

    if result.isUntagged and not isCase:
      warning "`untagged` does not working with non-case field", identNode[0]
  else:
    expectKind identNode, {nnkIdent, nnkPragmaExpr}
  
  result.isCase = isCase


proc init(Self: typedesc[Field], recCase: NimNode): Self =
  # Get field from case statement
  expectKind recCase, nnkRecCase

  let identDefs = recCase[0]
  result = Self.init(identDefs=identDefs, isCase=true)

  let branches = recCase[1..recCase.len-1]

  for branch in branches:
    case branch.kind
    of nnkOfBranch:
      let
        # for future code generation
        # we need to safe ofBranch without body
        condition = branch.copyWithoutChild(branch.len-1)
        recList = branch[branch.len-1]
        fields = getFields(recList=recList)

      result.branches.add FieldBranch(
        kind: Of,
        condition: condition,
        fields: fields
      )
    of nnkElse:
      let
        recList = branch[0]
        fields = getFields(recList=recList)
      
      result.branches.add FieldBranch(
        kind: Else,
        fields: fields
      )
    else:
      expectKind branch, {nnkOfBranch, nnkElse}


proc getFields(recList: NimNode): seq[Field] =
  expectKind recList, {nnkRecList, nnkEmpty}

  if recList.kind != nnkEmpty:
    for fieldNode in recList:
      case fieldNode.kind
      of nnkIdentDefs:
        result.add Field.init(identDefs=fieldNode, isCase=false)
      of nnkRecCase:
        result.add Field.init(recCase=fieldNode)
      of nnkNilLit:
        # of/else:
        #   nil
        discard
      else:
        expectKind fieldNode, {nnkIdentDefs, nnkRecCase}


proc getInheritSym(objectTy: NimNode): Option[NimNode] =
  expectKind objectTy, nnkObjectTy

  let inherit = objectTy[1]

  if inherit.kind == nnkOfInherit:
    case inherit[0].kind
    of nnkSym:
      result = some inherit[0]
    of nnkBracketExpr:
      result = some inherit[0][0]
    else:
      expectKind inherit[0], {nnkSym, nnkBracketExpr}


proc init(Self: typedesc[Struct], sym: NimNode): Self =
  # Get temp `ObjectTy` from symbol of type
  expectKind sym, nnkSym

  let typeDef = sym.getImpl

  if typeDef.kind == nnkNilLit:
    error("No type implementation. Maybe it is a built-in type.")
  else:
    expectKind typeDef, nnkTypeDef

  let typeImpl = typeDef[2]

  case typeImpl.kind
  of nnkSym:  # type Foo = Bar
    # Error on aliases
    error(
      "Alias is not supported. Use original or distinct type instead.",
      typeDef[0]
    )
  of nnkRefTy:
    case typeImpl[0].kind
    of nnkSym:  # type Foo = ref Bar
      result = Self.init typeImpl[0]
      # use alias type
      result.sym = sym
      # Clear generics that we get from recursive call
      reset result.genericParams
    of nnkObjectTy:  # type Foo = ref object
      # type Foo = ref object of Bar
      let inheritSym = getInheritSym(typeImpl[0])
      if inheritSym.isSome:
        let parent = Struct.init inheritSym.unsafeGet
        result.features = parent.features
        result.fields = parent.fields

      result.fields.add getFields(recList=typeImpl[0][2])

      result = Self(
        isRef: true,
        sym: sym,
        fields: result.fields,
        enumSym: genSym(nskType, sym.strVal),
        enumUnknownFieldSym: genSym(nskEnumField, "Unknown"),
        features: result.features
      )
    else:
      expectKind typeImpl[0], {nnkSym, nnkObjectTy}
  of nnkObjectTy:  # type Foo = object
    # type Foo = object of Bar
    let inheritSym = getInheritSym(typeImpl)
    if inheritSym.isSome:
      let parent = Struct.init inheritSym.unsafeGet
      result.features = parent.features
      result.fields = parent.fields
    
    result.fields.add getFields(recList=typeImpl[2])

    result = Self(
      isRef: false,
      sym: sym,
      fields: result.fields,
      enumSym: genSym(nskType, sym.strVal),
      enumUnknownFieldSym: genSym(nskEnumField, "Unknown"),
      features: result.features
    )
  of nnkDistinctTy:  # type Foo = distinct Bar
    # Get original type
    let originType =
      case typeImpl[0].kind
      of nnkSym:
        typeImpl[0]
      of nnkBracketExpr:
        typeImpl[0][0]
      else:
        expectKind typeImpl[0], {nnkSym, nnkBracketExpr}
        nil

    result = Self.init originType
    # Use sym from distinct type
    result.sym = sym
    result.isDistinct = true
    # Clear generics that we get from recursive call
    reset result.genericParams
  of nnkEnumTy:
    error("Enum is serializable by default.", typeDef[0])
  of nnkInfix, nnkTypeClassTy:
    error("Type class is not supported.", typeDef[0])
  of nnkTupleConstr, nnkTupleTy:
    error("Tuple is serializable by default.", typeDef[0])
  else:
    expectKind typeImpl, {nnkRefTy, nnkObjectTy, nnkDistinctTy}
  
  #[
      typeDef[0]
        |-------|
        |       |
        v       v
  type Test {.test.} = object
                ^
                |
                |
          typeDef[0][1]
  ]#
  if typeDef[0].kind == nnkPragmaExpr:
    result.features.fill(pragmas=typeDef[0])

  if typeDef[1].kind == nnkGenericParams:
    result.genericParams = some typeDef[1]
  
  result.flattenFields = flatten result.fields
{.pop.}
