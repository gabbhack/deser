import std/[
  options,
  macros,
  strutils,
  strformat,
  typetraits,
  sets,
  tables,
  enumerate
]

from error import
  raiseInvalidValue,
  raiseMissingField,
  UnexpectedString,
  UnexpectedSigned,
  UnexpectedFloat


from ../magic/des/utils {.all.} import
  genPrimitive,
  genArray,
  visitEnumIntBody,
  visitRangeIntBody,
  visitRangeFloatBody,
  rangeUnderlyingType

from helpers import
  implVisitor,
  NoneSeed,
  IgnoredAny


when defined(release):
  {.push inline, checks: off.}

{.push used.}
proc deserialize*[T](self: NoneSeed[T], deserializer: var auto): T =
  mixin deserialize

  result = T.deserialize(deserializer)


type
  IgnoredAnyVisitorRaw[Value] = object
  IgnoredAnyVisitor = IgnoredAnyVisitorRaw[IgnoredAny]

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


type
  BoolVisitorRaw[Value] = object
  BoolVisitor = BoolVisitorRaw[bool]

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


type
  CharVisitorRaw[Value] = object
  CharVisitor = CharVisitorRaw[char]

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


type
  StringVisitorRaw[Value] = object
  StringVisitor = StringVisitorRaw[string]

implVisitor(StringVisitor, public=true)

proc expecting*(self: StringVisitor): string = "a string"

proc visitString*(self: StringVisitor, value: string): self.Value = value

proc deserialize*(Self: typedesc[string], deserializer: var auto): Self =
  mixin deserializeString

  deserializer.deserializeString(StringVisitor())


type
  BytesVisitorRaw[Value] = object
  BytesVisitor[T: seq or array] = BytesVisitorRaw[T]

implVisitor(BytesVisitor, public=true)

proc expecting*(self: BytesVisitor): string = "byte array or seq"

proc expecting*[T](self: BytesVisitor[T]): string = $T

proc visitBytes*[T](self: BytesVisitor[T], value: openArray[byte]): T =
  when T is array:
    if value.len == T.len:
      copyMem result[0].unsafeAddr, value[0].unsafeAddr, T.len * sizeof(result[0])
    else:
      raiseInvalidLength(value.len, T.len)
  else:
    @value


proc visitSeq*[T](self: BytesVisitor[T], sequence: var auto): T =
  mixin items, sizeHint

  when T is array:
    for index, i in enumerate(items[byte](sequence)):
      result[index] = i
  else:
    result = newSeqOfCap[byte](sequence.sizeHint.get(10))
    for i in items[byte](sequence):
      result.add i


proc deserialize*(Self: typedesc[seq[byte]], deserializer: var auto): Self =
  mixin deserializeBytes

  deserializer.deserializeBytes(BytesVisitor[Self]())


proc deserialize*[Size](Self: typedesc[array[Size, byte]], deserializer: var auto): Self =
  mixin deserializeBytes

  deserializer.deserializeBytes(BytesVisitor[Self]())


type
  OptionVisitorRaw[Value] = object
  OptionVisitor[T] = OptionVisitorRaw[Option[T]]

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


type
  SeqVisitorRaw[Value] = object
  SeqVisitor[T] = SeqVisitorRaw[seq[T]]

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


type
  ArrayVisitorRaw[Value] = object
  ArrayVisitor[T] = ArrayVisitorRaw[T]

implVisitor(ArrayVisitor, public=true)

proc expecting*(self: ArrayVisitor): string = "array"

proc expecting*[T](self: ArrayVisitor[T]): string = $T

proc visitSeq*[T](self: ArrayVisitor[T], sequence: var auto): T =
  mixin nextElement

  genArray(T.high, type(result[0]))


proc deserialize*[Size](Self: typedesc[array[Size, not byte]], deserializer: var auto): Self =
  mixin deserializeArray

  deserializer.deserializeArray(Self.len, ArrayVisitor[Self]())


type
  EnumVisitorRaw[Value] = object
  EnumVisitor[T] = EnumVisitorRaw[T]

implVisitor(EnumVisitor, public=true)

proc expecting*(self: EnumVisitor): string = "enum"

proc expecting*[T: enum](self: EnumVisitor[T]): string = &"enum `{$T}`"

proc visitString*[T: enum](self: EnumVisitor[T], value: sink string): T = parseEnum[T](value)

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


type
  TupleVisitorRaw[Value] = object
  TupleVisitor[T] = TupleVisitorRaw[T]

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


type
  SetVisitorRaw[Value] = object
  SetVisitor[T] = SetVisitorRaw[set[T]]

implVisitor(SetVisitor, public=true)

proc expecting*(self: SetVisitor): string = "a set"

proc expecting*[T](self: SetVisitor[T]): string = &"a set of `{$T}`"

proc visitSeq*[T](self: SetVisitor[T], sequence: var auto): set[T] =
  for item in items[T](sequence):
    result.incl item


proc deserialize*[T](Self: typedesc[set[T]], deserializer: var auto): Self =
  mixin
    deserializeSeq

  deserializer.deserializeSeq(SetVisitor[T]())


type
  OrderedSetVisitorRaw[Value] = object
  OrderedSetVisitor[T] = OrderedSetVisitorRaw[OrderedSet[T]]

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


type
  HashSetVisitorRaw[Value] = object
  HashSetVisitor[T] = HashSetVisitorRaw[HashSet[T]]

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


type
  TableVisitorRaw[Value] = object
  TableVisitor[Key, Value] = TableVisitorRaw[Table[Key, Value]]

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


type
  OrderedTableVisitorRaw[Value] = object
  OrderedTableVisitor[Key, Value] = OrderedTableVisitorRaw[OrderedTable[Key, Value]]

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


type
  RangeVisitorRaw[Value] = object
  RangeVisitor[T] = RangeVisitorRaw[T]

implVisitor(RangeVisitor, public=true)

proc expecting*(self: RangeVisitor): string = "a range"

proc expecting*[T: range](self: RangeVisitor[T]): string = $T

proc visitInt8*[T: range](self: RangeVisitor[T], value: int8): T = visitRangeIntBody()
proc visitInt16*[T: range](self: RangeVisitor[T], value: int16): T = visitRangeIntBody()
proc visitInt32*[T: range](self: RangeVisitor[T], value: int32): T = visitRangeIntBody()
proc visitInt64*[T: range](self: RangeVisitor[T], value: int64): T = visitRangeIntBody()

proc visitUint8*[T: range](self: RangeVisitor[T], value: uint8): T = visitRangeIntBody()
proc visitUint16*[T: range](self: RangeVisitor[T], value: uint16): T = visitRangeIntBody()
proc visitUint32*[T: range](self: RangeVisitor[T], value: uint32): T = visitRangeIntBody()
proc visitUint64*[T: range](self: RangeVisitor[T], value: uint64): T = visitRangeIntBody()

proc visitFloat32*[T](self: RangeVisitor[T], value: float32): T = visitRangeFloatBody()
proc visitFloat64*[T](self: RangeVisitor[T], value: float64): T = visitRangeFloatBody()

proc deserialize*(Self: typedesc[range], deserializer: var auto): Self =
  mixin
    deserializeInt8,
    deserializeInt16,
    deserializeInt32,
    deserializeInt64,
    deserializeUint8,
    deserializeUint16,
    deserializeUint32,
    deserializeUint64,
    deserializeFloat32,
    deserializeFloat64

  type UnderlyingType = rangeUnderlyingType(Self)

  when UnderlyingType is int8:
    deserializer.deserializeInt8(RangeVisitor[Self]())
  elif UnderlyingType is int16:
    deserializer.deserializeInt16(RangeVisitor[Self]())
  elif UnderlyingType is int32:
    deserializer.deserializeInt32(RangeVisitor[Self]())
  elif UnderlyingType is int64:
    deserializer.deserializeInt64(RangeVisitor[Self]())
  elif UnderlyingType is uint8:
    deserializer.deserializeUint8(RangeVisitor[Self]())
  elif UnderlyingType is uint16:
    deserializer.deserializeUint16(RangeVisitor[Self]())
  elif UnderlyingType is uint32:
    deserializer.deserializeUint32(RangeVisitor[Self]())
  elif UnderlyingType is uint64:
    deserializer.deserializeUint64(RangeVisitor[Self]())
  elif UnderlyingType is float32:
    deserializer.deserializeFloat32(RangeVisitor[Self]())
  elif UnderlyingType is float64:
    deserializer.deserializeFloat64(RangeVisitor[Self]())
  else:
    deserializer.deserializeInt64(RangeVisitor[Self]())
{.pop.}

proc deserialize*(Self: typedesc[ref], deserializer: var auto): Self =
  mixin deserialize

  new result
  result[] = pointerBase(Self).deserialize(deserializer)

when defined(release):
  {.pop.}
