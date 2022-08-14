import std/[macros, options, tables]

import ../pragmas


type
  Struct = object of RootObj
    isRef*: bool
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
    self.defaultValue = some values[0]


proc init(Self: typedesc[FieldFeatures | StructFeatures], pragmas: NimNode): Self =
  # Check whether the field or object contains our pragmas
  expectKind pragmas, {nnkPragma, nnkPragmaExpr}

  let pragmas =
    if pragmas.kind == nnkPragma:
      pragmas
    else:
      # for object
      pragmas[1]

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
        # I do not know what is going on here
        values = if pragma.len > 1: pragma[1..pragma.len-1] else: @[]
      result.fill(sym, values)
    else:
      expectKind pragma, {nnkSym, nnkCall}

  when Self is FieldFeatures:
    if result.skipSerializing and result.serializeWith.isSome:
      warning "`serializeWith` does not working with `skipSerializing`", pragmas
    
    if result.skipDeserializing and result.deserializeWith.isSome:
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
    result.features = FieldFeatures.init(pragmas=identNode[1])

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


proc init(Self: typedesc[Struct], sym: NimNode): Self =
  # Get temp `ObjectTy` from symbol of type
  expectKind sym, nnkSym

  let typeDef = sym.getImpl

  expectKind typeDef, nnkTypeDef

  let typeImpl = typeDef[2]

  case typeImpl.kind
  of nnkSym:
    # For alias types
    # e.g. type Foo = Bar
    # recursively calling ourselves
    result = Self.init typeImpl
  of nnkRefTy:
    case typeImpl[0].kind
    of nnkSym:
      # For type Foo = ref Bar
      result = Self.init typeImpl[0]
      # use alias type
      result.sym = sym
    of nnkObjectTy:
      # For type Foo = ref object
      result = Self(
        isRef: true,
        sym: sym,
        fields: getFields(recList=typeImpl[0][2]),
        enumSym: genSym(nskType, sym.strVal),
        enumUnknownFieldSym: genSym(nskEnumField, "Unknown")
      )
    else:
      expectKind typeImpl[0], {nnkSym, nnkObjectTy}
  of nnkObjectTy:
    # For type Foo = object
    result = Self(
      isRef: false,
      sym: sym,
      fields: getFields(recList=typeImpl[2]),
      enumSym: genSym(nskType, sym.strVal),
      enumUnknownFieldSym: genSym(nskEnumField, "Unknown")
    )
  else:
    expectKind typeImpl, {nnkSym, nnkRefTy, nnkObjectTy}
  
  #[
      typeDef[0]
        |-------|
        |       |
        v       v
  type Test {.test.} = object
                |
                |
                v
          typeDef[0][1]
  ]#
  if typeDef[0].kind == nnkPragmaExpr:
    result.features = StructFeatures.init typeDef[0]

  if typeDef[1].kind == nnkGenericParams:
    result.genericParams = some typeDef[1]
  
  result.flattenFields = flatten result.fields
{.pop.}
