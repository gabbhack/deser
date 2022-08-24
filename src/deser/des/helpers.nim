##[
.. Note:: This section of the documentation is being supplemented.

# Visitor

# SeqAccess

# MapAccess

# Deserializer
]##

import std/[
  options
]

from error import
  raiseInvalidType,
  raiseInvalidValue,
  raiseDuplicateField,
  raiseInvalidLength,
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

from ../magic/sharedutils {.all.} import maybePublic


type
  NoneSeed*[Value] = object
  IgnoredAny* = object ##[
The type to skip some elements. Used when skip pragmas are used.
  ]##


template implVisitor*(selfType: typed, public: static[bool] = false) {.dirty.} = ##[
Generate forward declarations and default implementation for [Visitor](#visitor).
]##
  bind
    raiseInvalidType,
    UnexpectedBool,
    UnexpectedSigned,
    UnexpectedUnsigned,
    UnexpectedFloat,
    UnexpectedString,
    UnexpectedBytes,
    UnexpectedOption,
    UnexpectedSeq,
    UnexpectedMap,
    maybePublic

  maybePublic(public):
    # implementation expected
    proc expecting(self: selfType): string

    when defined(release):
      {.push inline.}

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


template implSeqAccess*(selfType: typed{`type`}, public: static[bool] = false) {.dirty.} = ##[
Generate forward declarations and default implementation for [SeqAccess](#seqaccess).
]##
  bind
    Option,
    NoneSeed,
    maybePublic

  maybePublic(public):
    # implementation expected
    proc nextElementSeed(self: var selfType, seed: auto): Option[seed.Value]

    when defined(release):
      {.push inline.}

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


template implMapAccess*(selfType: typed{`type`}, public: static[bool] = false) {.dirty.} = ##[
Generate forward declarations and default implementation for [MapAccess](#mapaccess).
]##
  bind
    Option,
    unsafeGet,
    isSome,
    some,
    NoneSeed,
    maybePublic

  maybePublic(public):
    # implementation expected
    proc nextKeySeed(self: var selfType, seed: auto): Option[seed.Value]

    proc nextValueSeed(self: var selfType, seed: auto): seed.Value

    when defined(release):
      {.push inline.}

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


template implDeserializer*(selfType: typed{`type`}, public: static[bool] = false) {.dirty.} = ##[
Generate forward declarations for [Deserializer](#deserializer).
]##
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


template implDeserializer*(selfType: typed{`type`}, public: static[bool] = false, defaultBody: untyped) {.dirty.} = ##[
Generate [Deserializer](#deserializer) procedures with `defaultBody` as implementation.
]##
  bind maybePublic

  maybePublic(public):
    proc deserializeAny[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody

    proc deserializeBool[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody

    proc deserializeInt8[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody
    proc deserializeInt16[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody
    proc deserializeInt32[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody
    proc deserializeInt64[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody

    proc deserializeUint8[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody
    proc deserializeUint16[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody
    proc deserializeUint32[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody
    proc deserializeUint64[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody

    proc deserializeFloat32[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody
    proc deserializeFloat64[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody

    proc deserializeChar[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody

    proc deserializeString[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody

    proc deserializeBytes[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody

    proc deserializeOption[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody

    proc deserializeSeq[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody

    proc deserializeMap[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody

    proc deserializeStruct[Self: selfType](self: var Self, name: static[string], fields: static[array], visitor: auto): visitor.Value = defaultBody

    proc deserializeIdentifier[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody

    proc deserializeEnum[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody

    proc deserializeIgnoredAny[Self: selfType](self: var Self, visitor: auto): visitor.Value = defaultBody

    proc deserializeArray[Self: selfType](self: var Self, len: static[int], visitor: auto): visitor.Value = defaultBody
