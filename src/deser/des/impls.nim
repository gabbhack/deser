import std/[
  options,
  macros,
  strutils,
  strformat,
  typetraits,
  sets,
  tables
]

from error import
  raiseInvalidValue,
  raiseMissingField,
  UnexpectedString


from ../magic/des/utils {.all.} import
  genPrimitive,
  genEnumCase,
  genArray,
  visitEnumIntBody

from helpers import
  Visitor,
  NoneSeed,
  IgnoredAny,
  implVisitor


when defined(release):
  {.push noinit, inline, checks: off.}

{.push used.}
proc deserialize*[T](self: NoneSeed[T], deserializer: var auto): T =
  mixin deserialize

  result = T.deserialize(deserializer)


type IgnoredAnyVisitor = Visitor[IgnoredAny]

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
    discard nextValue[IgnoredAny](map)

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

proc visitString*[T](self: EnumVisitor[T], value: sink string): T =
  # HACK: you cant use generic as sym
  genEnumCase(genericParams(typeof(self)).get(0))


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

  for name, field in fieldPairs(result):
    field = (
      let temp = nextElement[field.type](sequence)
      if temp.isSome:
        temp.unsafeGet
      else:
        raiseMissingField(name)
    )


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
