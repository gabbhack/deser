import std/[options]

from impls import NoneSeed
from error import
    raiseInvalidType,
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


template implVisitor*(selfType: typed{`type`}, returnType: typed{`type`}) {.dirty.} =
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

  template Value(self: selfType): typedesc = returnType

  # implementation expected
  proc expecting(self: selfType): string {.inline.}

  {.push noinit, inline, used.}
  # forward declaration
  proc visitBool[Self: selfType](self: Self, value: bool): returnType
  proc visitInt8[Self: selfType](self: Self, value: int8): returnType
  proc visitInt16[Self: selfType](self: Self, value: int16): returnType
  proc visitInt32[Self: selfType](self: Self, value: int32): returnType
  proc visitInt64[Self: selfType](self: Self, value: int64): returnType

  proc visitUint8[Self: selfType](self: Self, value: uint8): returnType
  proc visitUint16[Self: selfType](self: Self, value: uint16): returnType
  proc visitUint32[Self: selfType](self: Self, value: uint32): returnType
  proc visitUint64[Self: selfType](self: Self, value: uint64): returnType

  proc visitFloat32[Self: selfType](self: Self, value: float32): returnType
  proc visitFloat64[Self: selfType](self: Self, value: float64): returnType

  proc visitChar[Self: selfType](self: Self, value: char): returnType
  proc visitString[Self: selfType](self: Self, value: string): returnType

  proc visitBytes[Self: selfType](self: Self, value: openArray[byte]): returnType

  proc visitNone[Self: selfType](self: Self): returnType
  proc visitSome[Self: selfType](self: Self, deserializer: var auto): returnType

  proc visitSeq[Self: selfType](self: Self, sequence: var auto): returnType
  proc visitMap[Self: selfType](self: Self, map: var auto): returnType

  # default implementation
  proc visitBool[Self: selfType](self: Self, value: bool): returnType = raiseInvalidType(UnexpectedBool(value), self)

  proc visitInt8[Self: selfType](self: Self, value: int8): returnType = self.visitInt64(value.int64)
  proc visitInt16[Self: selfType](self: Self, value: int16): returnType = self.visitInt64(value.int64)
  proc visitInt32[Self: selfType](self: Self, value: int32): returnType = self.visitInt64(value.int64)
  proc visitInt64[Self: selfType](self: Self, value: int64): returnType = raiseInvalidType(UnexpectedSigned(value), self)

  proc visitUint8[Self: selfType](self: Self, value: uint8): returnType = self.visitUint64(value.uint64)
  proc visitUint16[Self: selfType](self: Self, value: uint16): returnType = self.visitUint64(value.uint64)
  proc visitUint32[Self: selfType](self: Self, value: uint32): returnType = self.visitUint64(value.uint64)
  proc visitUint64[Self: selfType](self: Self, value: uint64): returnType = raiseInvalidType(UnexpectedUnsigned(value), self)

  proc visitFloat32[Self: selfType](self: Self, value: float32): returnType = self.visitFloat64(value.float64)
  proc visitFloat64[Self: selfType](self: Self, value: float64): returnType = raiseInvalidType(UnexpectedFloat(value), self)

  proc visitChar[Self: selfType](self: Self, value: char): returnType = self.visitString($value)
  proc visitString[Self: selfType](self: Self, value: string): returnType = raiseInvalidType(UnexpectedString(value), self)

  proc visitBytes[Self: selfType](self: Self, value: openArray[byte]): returnType = raiseInvalidType(UnexpectedBytes(@value), self)

  proc visitNone[Self: selfType](self: Self): returnType = raiseInvalidType(UnexpectedOption(), self)
  proc visitSome[Self: selfType](self: Self, deserializer: var auto): returnType = raiseInvalidType(UnexpectedOption(), self)

  proc visitSeq[Self: selfType](self: Self, sequence: var auto): returnType = raiseInvalidType(UnexpectedSeq(), self)
  proc visitMap[Self: selfType](self: Self, map: var auto): returnType = raiseInvalidType(UnexpectedMap(), self)
  {.pop.}


template implSeqAccess*(selfType: typed{`type`}) {.dirty.} =
  bind Option
  bind NoneSeed

  # implementation expected
  proc nextElementSeed(self: var selfType, seed: auto): Option[seed.Value]

  {.push noinit, inline.}
  # default implementation
  proc nextElement[Self: selfType](self: var Self, Value: typedesc): Option[Value] =
    self.nextElementSeed(NoneSeed[Value]())
  
  proc sizeHint[Self: selfType](self: Self): Option[uint] = none(uint)
  {.pop.}


template implMapAccess*(selfType: typed{`type`}) {.dirty.} =
  bind Option
  bind unsafeGet
  bind isSome
  bind some
  bind NoneSeed

  # implementation expected
  proc nextKeySeed(self: var selfType, seed: auto): Option[seed.Value]

  proc nextValueSeed(self: var selfType, seed: auto): seed.Value

  {.push noinit, inline.}
  # default implementation
  proc nextEntrySeed(self: var selfType, kseed: auto, vseed: auto): Option[(kseed.Value, vseed.Value)] =
    let keyOption = self.nextKeySeed(kseed)
    if keyOption.isSome:
      let
        key = keyOption.unsafeGet
        value = self.nextValueSeed(vseed)
      result = some (key, value)
    else:
      reset result
  
  proc nextKey(self: var selfType, Value: typedesc): Option[Value] =
    self.nextKeySeed(NoneSeed[Value]())
  
  proc nextValue(self: var selfType, Value: typedesc): Value =
    self.nextValueSeed(NoneSeed[Value]())
  
  proc nextEntry(self: var selfType, Key, Value: typedesc): Option[(Key, Value)] =
    self.nextEntrySeed(NoneSeed[Key](), NoneSeed[Value]())
  
  proc sizeHint[Self: selfType](self: Self): Option[uint] = none(uint)

  iterator keys(self: var selfType, Value: typedesc): Value =
    var keyOption = self.nextKey(Value)
    while keyOption.isSome:
      yield keyOption.unsafeGet
      keyOption = self.nextKey(Value)
  {.pop.}


template implDeserializer*(selfType: typed{`type`}) {.dirty.} =
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

  proc deserializeStruct(self: var selfType, visitor: auto): visitor.Value

  proc deserializeIdentifier(self: var selfType, visitor: auto): visitor.Value
