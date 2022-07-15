import std/[options, macros, strutils, strformat, typetraits, sets, tables]

from error import
    raiseInvalidType,
    raiseInvalidValue,
    raiseDuplicateField,
    UnexpectedBool,
    UnexpectedUnsigned,
    UnexpectedSigned,
    UnexpectedFloat,
    UnexpectedChar,
    UnexpectedString,
    UnexpectedBytes,
    UnexpectedOption,
    UnexpectedSeq,
    UnexpectedMap

from ../pragmas import lowerCased


type Visitor*[Value] = object


macro maybePublic(public: static[bool], body: untyped): untyped =
  if not public:
    result = body
  else:
    result = newStmtList()

    for element in body:
      if element.kind notin {nnkProcDef, nnkIteratorDef}:
        result.add element
      else:
        element[0] = nnkPostfix.newTree(
          ident "*",
          element[0]
        )
        result.add element


macro genPrimitive(T: typed{`type`}, deserializeMethod: untyped = nil, floats: static[bool] = false) =
  result = newStmtList()
  var
    visitorSym = bindSym "Visitor"
    selfIdent = ident "self"
    valueIdent = ident "value"
    deserializerIdent = ident "deserializer"
    visitorType = genSym(nskType, "Visitor")
    deserializeMethodIdent = (
      if deserializeMethod.kind != nnkNilLit:
        deserializeMethod
      else:
        ident "deserialize" & T.strVal.capitalizeAscii
    )
    typeStringLit = T.toStrLit
    procs = @[
      (ident "visitInt8", ident "int8"),
      (ident "visitInt16", ident "int16"),
      (ident "visitInt32", ident "int32"),
      (ident "visitInt64", ident "int64"),
      (ident "visitUint8", ident "uint8"),
      (ident "visitUint16", ident "uint16"),
      (ident "visitUint32", ident "uint32"),
      (ident "visitUint64", ident "uint64"),
    ]

    body = quote do:
      when type(value) is self.Value:
        value
      else:
        when self.Value is SomeUnsignedInt:
          when value is SomeSignedInt:
            if not (0 <= value and value.uint64 <= self.Value.high.uint64):
              raiseInvalidValue(UnexpectedSigned(value.int64), self)
          elif value is SomeUnsignedInt:
            if not (value.uint64 <= self.Value.high.uint64):
              raiseInvalidValue(UnexpectedUnsigned(value.uint64), self)
          else:
            {.error: "Unknown type `" & $self.Value & "`, expected int or uint".}
        elif self.Value is SomeSignedInt:
          when value is SomeSignedInt:
            if not (self.Value.low.int64 <= value.int64 and value.int64 <= self.Value.high.int64):
              raiseInvalidValue(UnexpectedSigned(value.int64), self)
          elif value is SomeUnsignedInt:
            if not (value.uint64 <= self.Value.high.uint64):
                raiseInvalidValue(UnexpectedUnsigned(value.uint64), self)
          else:
            {.error: "Unknown type `" & $self.Value() & "`, expected int or uint".}

        self.Value(value)
  
  result.add quote do:
    type `visitorType` = `visitorSym`[`T`]
    implVisitor(`visitorType`, true)

    proc expecting*(`selfIdent`: `visitorType`): string = `typeStringLit`

    proc deserialize*(`selfIdent`: typedesc[`T`], `deserializerIdent`: var auto): `T` =
      mixin `deserializeMethodIdent`

      deserializer.`deserializeMethodIdent`(`visitorType`())
  
  if floats:
    procs.add @[
      (ident "visitFloat32", ident "float32"),
      (ident "visitFloat64", ident "float64")
    ]

  for (procIdent, valueType) in procs:
    result.add quote do:
      proc `procIdent`*(`selfIdent`: `visitorType`, `valueIdent`: `valueType`): self.Value =
        `body`


type NoneSeed*[Value] = object


proc deserialize*[T](self: NoneSeed[T], deserializer: var auto): T {.noinit, inline.} =
  mixin deserialize

  result = T.deserialize(deserializer)


template implVisitor*(selfType: typed, public: static[bool] = false) {.dirty.} =
  bind raiseInvalidType
  bind UnexpectedBool
  bind UnexpectedSigned
  bind UnexpectedUnsigned
  bind UnexpectedFloat
  bind UnexpectedString
  bind UnexpectedBytes
  bind UnexpectedOption
  bind UnexpectedSeq
  bind UnexpectedMap
  bind maybePublic

  maybePublic(public):
    # implementation expected
    proc expecting(self: selfType): string

    when defined(release):
      {.push noinit, inline.}

    {.push used.}
    # forward declaration
    proc visitBool[Self: selfType](self: Self, value: bool): self.Value
    proc visitInt8[Self: selfType](self: Self, value: int8): self.Value
    proc visitInt16[Self: selfType](self: Self, value: int16): self.Value
    proc visitInt32[Self: selfType](self: Self, value: int32): self.Value
    proc visitInt64[Self: selfType](self: Self, value: int64): self.Value

    proc visitUint8[Self: selfType](self: Self, value: uint8): self.Value
    proc visitUint16[Self: selfType](self: Self, value: uint16): self.Value
    proc visitUint32[Self: selfType](self: Self, value: uint32): self.Value
    proc visitUint64[Self: selfType](self: Self, value: uint64): self.Value

    proc visitFloat32[Self: selfType](self: Self, value: float32): self.Value
    proc visitFloat64[Self: selfType](self: Self, value: float64): self.Value

    proc visitChar[Self: selfType](self: Self, value: char): self.Value
    proc visitString[Self: selfType](self: Self, value: sink string): self.Value

    proc visitBytes[Self: selfType](self: Self, value: openArray[byte]): self.Value

    proc visitNone[Self: selfType](self: Self): self.Value
    proc visitSome[Self: selfType](self: Self, deserializer: var auto): self.Value

    proc visitSeq[Self: selfType](self: Self, sequence: var auto): self.Value
    proc visitMap[Self: selfType](self: Self, map: var auto): self.Value

    # default implementation
    proc visitBool[Self: selfType](self: Self, value: bool): self.Value = raiseInvalidType(UnexpectedBool(value), self)

    proc visitInt8[Self: selfType](self: Self, value: int8): self.Value = self.visitInt64(value.int64)
    proc visitInt16[Self: selfType](self: Self, value: int16): self.Value = self.visitInt64(value.int64)
    proc visitInt32[Self: selfType](self: Self, value: int32): self.Value = self.visitInt64(value.int64)
    proc visitInt64[Self: selfType](self: Self, value: int64): self.Value = raiseInvalidType(UnexpectedSigned(value), self)

    proc visitUint8[Self: selfType](self: Self, value: uint8): self.Value = self.visitUint64(value.uint64)
    proc visitUint16[Self: selfType](self: Self, value: uint16): self.Value = self.visitUint64(value.uint64)
    proc visitUint32[Self: selfType](self: Self, value: uint32): self.Value = self.visitUint64(value.uint64)
    proc visitUint64[Self: selfType](self: Self, value: uint64): self.Value = raiseInvalidType(UnexpectedUnsigned(value), self)

    proc visitFloat32[Self: selfType](self: Self, value: float32): self.Value = self.visitFloat64(value.float64)
    proc visitFloat64[Self: selfType](self: Self, value: float64): self.Value = raiseInvalidType(UnexpectedFloat(value), self)

    proc visitChar[Self: selfType](self: Self, value: char): self.Value = self.visitString($value)
    proc visitString[Self: selfType](self: Self, value: sink string): self.Value = raiseInvalidType(UnexpectedString(value), self)

    proc visitBytes[Self: selfType](self: Self, value: openArray[byte]): self.Value = raiseInvalidType(UnexpectedBytes(@value), self)

    proc visitNone[Self: selfType](self: Self): self.Value = raiseInvalidType(UnexpectedOption(), self)
    proc visitSome[Self: selfType](self: Self, deserializer: var auto): self.Value = raiseInvalidType(UnexpectedOption(), self)

    proc visitSeq[Self: selfType](self: Self, sequence: var auto): self.Value = raiseInvalidType(UnexpectedSeq(), self)
    proc visitMap[Self: selfType](self: Self, map: var auto): self.Value = raiseInvalidType(UnexpectedMap(), self)
    {.pop.}

    when defined(release):
      {.pop.}


template implSeqAccess*(selfType: typed{`type`}, public: static[bool] = false) {.dirty.} =
  bind Option
  bind NoneSeed
  bind maybePublic

  maybePublic(public):
    # implementation expected
    proc nextElementSeed(self: var selfType, seed: auto): Option[seed.Value]

    when defined(release):
      {.push noinit, inline.}

    {.push used.}
    # default implementation
    proc nextElement[Value](self: var selfType): Option[Value] =
      self.nextElementSeed(NoneSeed[Value]())
    
    proc sizeHint[Self: selfType](self: Self): Option[int] = none(int)

    iterator items[Value](self: var selfType): Value =
      var elementOption = nextElement[Value](self)
      while elementOption.isSome:
        yield elementOption.unsafeGet
        elementOption = nextElement[Value](self)
    {.pop.}

    when defined(release):
      {.pop.}


template implMapAccess*(selfType: typed{`type`}, public: static[bool] = false) {.dirty.} =
  bind Option
  bind unsafeGet
  bind isSome
  bind some
  bind NoneSeed
  bind maybePublic

  maybePublic(public):
    # implementation expected
    proc nextKeySeed(self: var selfType, seed: auto): Option[seed.Value]

    proc nextValueSeed(self: var selfType, seed: auto): seed.Value

    when defined(release):
      {.push noinit, inline.}

    {.push used.}
    # default implementation
    proc nextEntrySeed(self: var selfType, kseed: auto, vseed: auto): Option[(kseed.Value, vseed.Value)] =
      let keyOption = self.nextKeySeed(kseed)
      if keyOption.isSome:
        let
          key = keyOption.unsafeGet
          value = self.nextValueSeed(vseed)
        some (key, value)
      else:
        # HACK: none (kseed.Value, vseed.Value) -> Error: expression 'none (Value, Value)' has no type (or is ambiguous)
        default(result.type)

    proc nextKey[Key](self: var selfType): Option[Key] =
      self.nextKeySeed(NoneSeed[Key]())

    proc nextValue[Value](self: var selfType): Value =
      self.nextValueSeed(NoneSeed[Value]())
    
    # named tuple because of https://github.com/nim-lang/Nim/issues/19979
    proc nextEntry[Key, Value](self: var selfType): Option[tuple[key: Key, value: Value]] =
      self.nextEntrySeed(NoneSeed[Key](), NoneSeed[Value]())
    
    proc sizeHint[Self: selfType](self: Self): Option[int] = none(int)

    iterator keys[Key](self: var selfType): Key =
      var keyOption = nextKey[Key](self)
      while keyOption.isSome:
        yield keyOption.unsafeGet
        keyOption = nextKey[Key](self)

    iterator pairs[Key, Value](self: var selfType): (Key, Value) =
      var entryOption = nextEntry[Key, Value](self)
      while entryOption.isSome:
        yield entryOption.unsafeGet
        entryOption = nextEntry[Key, Value](self)
    {.pop.}

    when defined(release):
      {.pop.}


template implDeserializer*(selfType: typed{`type`}, public: static[bool] = false) {.dirty.} =
  bind maybePublic

  maybePublic(public):
    # implementation expected
    proc deserializeAny(self: var selfType, visitor: auto): visitor.Value

    proc deserializeBool(self: var selfType, visitor: auto): visitor.Value

    proc deserializeInt8(self: var selfType, visitor: auto): visitor.Value
    proc deserializeInt16(self: var selfType, visitor: auto): visitor.Value
    proc deserializeInt32(self: var selfType, visitor: auto): visitor.Value
    proc deserializeInt64(self: var selfType, visitor: auto): visitor.Value

    proc deserializeUint8(self: var selfType, visitor: auto): visitor.Value
    proc deserializeUint16(self: var selfType, visitor: auto): visitor.Value
    proc deserializeUint32(self: var selfType, visitor: auto): visitor.Value
    proc deserializeUint64(self: var selfType, visitor: auto): visitor.Value

    proc deserializeFloat32(self: var selfType, visitor: auto): visitor.Value
    proc deserializeFloat64(self: var selfType, visitor: auto): visitor.Value

    proc deserializeChar(self: var selfType, visitor: auto): visitor.Value

    proc deserializeString(self: var selfType, visitor: auto): visitor.Value

    proc deserializeBytes(self: var selfType, visitor: auto): visitor.Value

    proc deserializeOption(self: var selfType, visitor: auto): visitor.Value

    proc deserializeSeq(self: var selfType, visitor: auto): visitor.Value

    proc deserializeMap(self: var selfType, visitor: auto): visitor.Value

    proc deserializeStruct(self: var selfType, name: static[string], fields: static[array], visitor: auto): visitor.Value

    proc deserializeIdentifier(self: var selfType, visitor: auto): visitor.Value

    proc deserializeEnum(self: var selfType, visitor: auto): visitor.Value

    proc deserializeIgnoredAny(self: var selfType, visitor: auto): visitor.Value

    proc deserializeArray(self: var selfType, len: static[int], visitor: auto): visitor.Value


when defined(release):
  {.push noinit, inline, checks: off.}

{.push used.}
type
  IgnoredAny* = object
  IgnoredAnyVisitor = Visitor[IgnoredAny]


proc deserialize*(Self: typedesc[IgnoredAny], deserializer: var auto): Self

implVisitor(IgnoredAnyVisitor, public=true)

proc expecting*(self: IgnoredAnyVisitor): string = "anything"

proc visitBool*(self: IgnoredAnyVisitor): self.Value = IgnoredAny()

proc visitInt8*(self: IgnoredAnyVisitor, value: int8): self.Value = IgnoredAny()

proc visitInt16*(self: IgnoredAnyVisitor, value: int16): self.Value = IgnoredAny()

proc visitInt32*(self: IgnoredAnyVisitor, value: int32): self.Value = IgnoredAny()

proc visitInt64*(self: IgnoredAnyVisitor, value: int64): self.Value = IgnoredAny()

proc visitUint8*(self: IgnoredAnyVisitor, value: uint8): self.Value = IgnoredAny()

proc visitUint16*(self: IgnoredAnyVisitor, value: uint16): self.Value = IgnoredAny()

proc visitUint32*(self: IgnoredAnyVisitor, value: uint32): self.Value = IgnoredAny()

proc visitUint64*(self: IgnoredAnyVisitor, value: uint64): self.Value = IgnoredAny()

proc visitFloat32*(self: IgnoredAnyVisitor, value: float32): self.Value = IgnoredAny()

proc visitFloat64*(self: IgnoredAnyVisitor, value: float64): self.Value = IgnoredAny()

proc visitChar*(self: IgnoredAnyVisitor, value: char): self.Value = IgnoredAny()

proc visitString*(self: IgnoredAnyVisitor, value: sink string): self.Value = IgnoredAny()

proc visitBytes*(self: IgnoredAnyVisitor, value: openArray[byte]): self.Value = IgnoredAny()

proc visitNone*(self: IgnoredAnyVisitor): self.Value = IgnoredAny()

proc visitSome*(self: IgnoredAnyVisitor, deserializer: var auto): self.Value =
  mixin deserialize

  deserialize(IgnoredAny, deserializer)


proc visitSeq*(self: IgnoredAnyVisitor, sequence: var auto): self.Value =
  mixin items

  for value in items[IgnoredAny](sequence):
    discard

  IgnoredAny()


proc visitMap*(self: IgnoredAnyVisitor, map: var auto): self.Value =
  mixin keys, nextValue

  for key in keys[IgnoredAny](map):
    let _ = nextValue[IgnoredAny](map)

  IgnoredAny()


proc deserialize*(Self: typedesc[IgnoredAny], deserializer: var auto): Self =
  mixin deserializeIgnoredAny

  deserializer.deserializeIgnoredAny(IgnoredAnyVisitor())


type BoolVisitor = Visitor[bool]

implVisitor(BoolVisitor, public=true)

proc expecting*(self: BoolVisitor): string = "a boolean"

proc visitBool*(self: BoolVisitor, value: bool): self.Value = value

proc deserialize*(Self: typedesc[bool], deserializer: var auto): Self =
  mixin deserializeBool

  deserializer.deserializeBool(BoolVisitor())


genPrimitive(int8)
genPrimitive(int16)
genPrimitive(int32)
genPrimitive(int64)
genPrimitive(int, deserializeInt64)

genPrimitive(uint8)
genPrimitive(uint16)
genPrimitive(uint32)
genPrimitive(uint64)
genPrimitive(uint, deserializeUint64)

genPrimitive(float32, floats=true)
genPrimitive(float64, floats=true)


type CharVisitor = Visitor[char]

implVisitor(CharVisitor, public=true)

proc expecting*(self: CharVisitor): string = "a character"

proc visitChar*(self: CharVisitor, value: char): self.Value = value

proc visitString*(self: CharVisitor, value: string): self.Value =
  if value.len == 1:
    value[0]
  else:
    raiseInvalidValue(UnexpectedString(value), self)


proc deserialize*(Self: typedesc[char], deserializer: var auto): Self =
  mixin deserializeChar

  deserializer.deserializeChar(CharVisitor())


type StringVisitor = Visitor[string]

implVisitor(StringVisitor, public=true)

proc expecting*(self: StringVisitor): string = "a string"

proc visitString*(self: StringVisitor, value: string): self.Value = value

proc deserialize*(Self: typedesc[string], deserializer: var auto): Self =
  mixin deserializeString

  deserializer.deserializeString(StringVisitor())


when defined(nimHasViews) and compiles((var x: openArray[int])):
  type BytesVisitor = Visitor[openArray[byte]]
else:
  type BytesVisitor = Visitor[seq[byte]]


implVisitor(BytesVisitor, public=true)

proc expecting*(self: BytesVisitor): string = "byte array"

proc visitBytes*(self: BytesVisitor, value: openArray[byte]): self.Value =
  when self.Value is openArray:
    value
  else:
    @value


type OptionVisitor[T] = Visitor[Option[T]]

implVisitor(OptionVisitor, public=true)

proc expecting*(self: OptionVisitor): string = "option"

proc expecting*[T](self: OptionVisitor[T]): string = &"option of `{$T}`"

proc visitNone*[T](self: OptionVisitor[T]): Option[T] = none T

proc visitSome*[T](self: OptionVisitor[T], deserializer: var auto): Option[T] =
  mixin deserialize

  some deserialize(T, deserializer)


proc deserialize*[T](Self: typedesc[Option[T]], deserializer: var auto): Self =
  mixin deserializeOption

  deserializer.deserializeOption(OptionVisitor[T]())


type SeqVisitor[T] = Visitor[seq[T]]

implVisitor(SeqVisitor, public=true)

proc expecting*(self: SeqVisitor): string = "sequence"

proc expecting*[T](self: SeqVisitor[T]): string = &"sequence of `{$T}`"

proc visitSeq*[T](self: SeqVisitor[T], sequence: var auto): seq[T] =
  mixin sizeHint

  let size = sizeHint(sequence).get(0)  

  result = newSeqOfCap[T](size)

  for item in items[T](sequence):
    result.add item


proc deserialize*[T](Self: typedesc[seq[T]], deserializer: var auto): Self =
  mixin deserializeSeq

  deserializer.deserializeSeq(SeqVisitor[T]())


type ArrayVisitor[Size, T] = Visitor[array[Size, T]]

implVisitor(ArrayVisitor, public=true)

proc expecting*(self: ArrayVisitor): string = "array"

proc expecting*[Size, T](self: ArrayVisitor[Size, T]): string = &"array[{$Size}, {$T}]"

macro genArray(size: static[int], T: typedesc): array =
  # [get(nextElement[T](sequence)), ...]
  result = nnkBracket.newTree()

  for i in 0..(size-1):
    result.add newCall(
      bindSym "get",
      newCall(
        nnkBracketExpr.newTree(
          ident "nextElement",
          ident "T"
        ),
        ident "sequence"
      )
    )


proc visitSeq*[Size, T](self: ArrayVisitor[Size, T], sequence: var auto): array[Size, T] =
  mixin nextElement

  # Size its a range (0..S)
  # S == len - 1
  genArray(Size.high + 1, T)


proc deserialize*[Size, T](Self: typedesc[array[Size, T]], deserializer: var auto): Self =
  mixin deserializeArray

  deserializer.deserializeArray(Self.len, ArrayVisitor[Size, T]())


type EnumVisitor[T: enum] = Visitor[T]

implVisitor(EnumVisitor, public=true)

proc expecting*(self: EnumVisitor): string = "enum"

proc expecting*[T](self: EnumVisitor[T]): string = &"enum `{$T}`"

macro genEnumCase(typ: typedesc[enum]): enum =
  let
    # some magic numbers
    typ = typ[1][0][0][1][2][0]
    typeDef = typ.getImpl
    enumTy = typeDef[2]
    lowerCasedSym = bindSym "lowerCased"
    lowerCased = (
      var temp = false
      if typeDef[0].kind == nnkPragmaExpr:
        for i in typeDef[0]:
          if i.kind == nnkPragma and i[0] == lowerCasedSym:
            temp = true
            break
      temp
    )

  result = nnkCaseStmt.newTree(ident "value")

  for variant in enumTy[1..enumTy.len-1]:
    let str = (
      if lowerCased:
        variant.strVal.toLowerAscii
      else:
        variant.strVal
    )
    result.add nnkOfBranch.newTree(
      newLit str,
      newStmtList(
        newDotExpr(
          typ,
          variant
        )
      )
    )
  
  result.add nnkElse.newTree(
    newCall(
      bindSym "raiseInvalidValue",
      newCall(
        bindSym "UnexpectedString",
        ident "value"
      ),
      ident "self"
    )
  )

proc visitString*[T](self: EnumVisitor[T], value: sink string): T =
  # HACK: you cant use generic as sym
  genEnumCase(genericParams(typeof(self)).get(0))


template visitEnumIntBody() {.dirty.} =
  if value.int64 in T.low.int64..T.high.int64:
    T(value)
  else:
    when value is SomeSignedInt:
      raiseInvalidValue(UnexpectedSigned(value), self)
    else:
      raiseInvalidValue(UnexpectedUnsigned(value), self)


proc visitInt8*[T](self: EnumVisitor[T], value: int8): T = visitEnumIntBody()
proc visitInt16*[T](self: EnumVisitor[T], value: int16): T = visitEnumIntBody()
proc visitInt32*[T](self: EnumVisitor[T], value: int32): T = visitEnumIntBody()
proc visitInt64*[T](self: EnumVisitor[T], value: int64): T = visitEnumIntBody()

proc visitUint8*[T](self: EnumVisitor[T], value: uint8): T = visitEnumIntBody()
proc visitUint16*[T](self: EnumVisitor[T], value: uint16): T = visitEnumIntBody()
proc visitUint32*[T](self: EnumVisitor[T], value: uint32): T = visitEnumIntBody()
proc visitUint64*[T](self: EnumVisitor[T], value: uint64): T = visitEnumIntBody()


proc deserialize*(Self: typedesc[enum], deserializer: var auto): Self =
  mixin deserializeEnum

  deserializer.deserializeEnum(EnumVisitor[Self]())


type TupleVisitor[T: tuple] = Visitor[T]

implVisitor(TupleVisitor, public=true)

proc expecting*(self: TupleVisitor): string = "a tuple"

proc expecting*[T](self: TupleVisitor[T]): string = &"{$T}"

proc visitSeq*[T](self: TupleVisitor[T], sequence: var auto): T =
  mixin nextElement

  result = default(T)

  for field in fields(result):
    field = nextElement[field.type](sequence).get()


proc deserialize*(Self: typedesc[tuple], deserializer: var auto): Self =
  mixin deserializeArray

  deserializer.deserializeArray(tupleLen(Self), TupleVisitor[Self]())


type SetVisitor[T] = Visitor[set[T]]

implVisitor(SetVisitor, public=true)

proc expecting*(self: SetVisitor): string = "a set"

proc expecting*[T](self: SetVisitor[T]): string = &"a set of `{$T}`"

proc visitSeq*[T](self: SetVisitor[T], sequence: var auto): set[T] =
  for item in items[T](sequence):
    result.incl item


proc deserialize*[T](Self: typedesc[set[T]], deserializer: var auto): Self =
  mixin deserializeSeq

  deserializer.deserializeSeq(SetVisitor[T]())


type OrderedSetVisitor[T] = Visitor[OrderedSet[T]]

implVisitor(OrderedSetVisitor, public=true)

proc expecting*(self: OrderedSetVisitor): string = "a set"

proc expecting*[T](self: OrderedSetVisitor[T]): string = &"a set of `{$T}`"

proc visitSeq*[T](self: OrderedSetVisitor[T], sequence: var auto): OrderedSet[T] =
  mixin sizeHint

  let size = sequence.sizeHint().get(64)

  result = initOrderedSet[T](size)

  for item in items[T](sequence):
    result.incl item


proc deserialize*[T](Self: typedesc[OrderedSet[T]], deserializer: var auto): Self =
  mixin deserializeSeq

  deserializer.deserializeSeq(OrderedSetVisitor[T]())


type HashSetVisitor[T] = Visitor[HashSet[T]]

implVisitor(HashSetVisitor, public=true)

proc expecting*(self: HashSetVisitor): string = "a set"

proc expecting*[T](self: HashSetVisitor[T]): string = &"a set of `{$T}`"

proc visitSeq*[T](self: HashSetVisitor[T], sequence: var auto): HashSet[T] =
  mixin sizeHint

  let size = sequence.sizeHint().get(64)

  result = initHashSet[T](size)

  for item in items[T](sequence):
    result.incl item


proc deserialize*[T](Self: typedesc[HashSet[T]], deserializer: var auto): Self =
  mixin deserializeSeq

  deserializer.deserializeSeq(HashSetVisitor[T]())


type TableVisitor[Key, Value] = Visitor[Table[Key, Value]]

implVisitor(TableVisitor, public=true)

proc expecting*(self: TableVisitor): string = "a table"

proc expecting*[Key, Value](self: TableVisitor[Key, Value]): string = &"a table with type of key `{$Key}` and type of value `{$Value}`"

proc visitMap*[Key, Value](self: TableVisitor[Key, Value], map: var auto): Table[Key, Value] =
  mixin pairs, sizeHint

  let size = map.sizeHint().get(32)

  result = initTable[Key, Value](size)

  for (key, value) in pairs[Key, Value](map):
    result[key] = value


proc deserialize*[Key, Value](Self: typedesc[Table[Key, Value]], deserializer: var auto): Self =
  deserializer.deserializeMap(TableVisitor[Key, Value]())


type OrderedTableVisitor[Key, Value] = Visitor[OrderedTable[Key, Value]]

implVisitor(OrderedTableVisitor, public=true)

proc expecting*(self: OrderedTableVisitor): string = "a table"

proc expecting*[Key, Value](self: OrderedTableVisitor[Key, Value]): string = &"a table with type of key `{$Key}` and type of value `{$Value}`"

proc visitMap*[Key, Value](self: OrderedTableVisitor[Key, Value], map: var auto): OrderedTable[Key, Value] =
  mixin pairs, sizeHint

  let size = map.sizeHint().get(32)

  result = initOrderedTable[Key, Value](size)

  for (key, value) in pairs[Key, Value](map):
    result[key] = value


proc deserialize*[Key, Value](Self: typedesc[OrderedTable[Key, Value]], deserializer: var auto): Self =
  deserializer.deserializeMap(OrderedTableVisitor[Key, Value]())

{.pop.}

when defined(release):
  {.pop.}
