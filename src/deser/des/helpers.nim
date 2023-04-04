##[
This module contains templates to help you reduce the amount of boilerplate when writing [Deserializer](#deserializer) or [Visitor](#visitor) objects.

# Visitor
To get the Nim data type from any data format, you need to write an object that implements the [Visitor](https://en.wikipedia.org/wiki/Visitor_pattern) pattern.
When deserializing, you pass your `Visitor` object to the deserializer. Next, the deserializer, depending on what type of data it encountered in the raw data, calls a method from the `Visitor` object. 

Your `Visitor` must implement the following methods:
```nim
proc expecting(self: Self): string

proc visitBool(self: Self, value: bool): MyType
proc visitInt8(self: Self, value: int8): MyType
proc visitInt16(self: Self, value: int16): MyType
proc visitInt32(self: Self, value: int32): MyType
proc visitInt64(self: Self, value: int64): MyType

proc visitUint8(self: Self, value: uint8): MyType
proc visitUint16(self: Self, value: uint16): MyType
proc visitUint32(self: Self, value: uint32): MyType
proc visitUint64(self: Self, value: uint64): MyType

proc visitFloat32(self: Self, value: float32): MyType
proc visitFloat64(self: Self, value: float64): MyType

proc visitChar(self: Self, value: char): MyType
proc visitString(self: Self, value: sink string): MyType

proc visitBytes(self: Self, value: openArray[byte]): MyType

proc visitNone(self: Self): MyType
proc visitSome(self: Self, deserializer: var auto): MyType

proc visitSeq(self: Self, sequence: var auto): MyType
proc visitMap(self: Self, map: var auto): MyType
```
where `Self` is the type of your `Visitor` object and `MyType` is the type you want to get from the deserializer.

The `expecting` method is used to generate a meaningful error message when the deserializer encounters an unexpected type of data. For example, if you expect a `bool` value, but the deserializer encounters a `string`, the error message will be something like `Expected bool, but got string`.

As you can see, no matter what type of data the deserializer encounters, your `Visitor` must return your type.
Of course, not every type can be derived from `bool` or `None`. In such a case, it is recommended to throw out the exception. 

.. Note:: The library, at the moment, does not restrict in any way which exceptions you throw, but it is **recommended** to use the [InvalidType](errors.html#InvalidType) exception with the [raiseInvalidType](errors.html#raiseInvalidType%2CUnexpected%2Cauto) procedure. `raiseInvalidType` uses the `expecting` method to generate a meaningful error message.

Let's write a `Visitor` for our type that accepts only even numbers.
It is painful to write an error for every unexpected type on your own, so we use the [implVisitor](#implVisitor.t%2Ctyped%2Cstatic[bool]) template. The `implVisitor` generates methods but you can override them.
```nim
import deser

type
  EvenInt = distinct int
  EvenIntVisitor = object

proc `$`(self: EvenInt): string = $self.int

# implVisitor requires that Visitor has a Value parameter. Value is your type.
template Value(visitor: EvenIntVisitor): type = EvenInt

#[
You can specify Value in a different way:

type
  EvenInt = distinct int
  HackType[Value] = object
  EvenIntVisitor = HackType[EvenInt]

echo EvenIntVisitor.Value
echo EvenIntVisitor().Value
]#

# The body of the methods is not much different, so let's write a template and use it.
template visitBody: EvenInt {.dirty.} =
  if value mod 2 == 0:
    EvenInt(value)
  else:
    when value is SomeSignedInt:
      raiseInvalidType(initUnexpectedSigned(value), self)
    else:
      raiseInvalidType(initUnexpectedUnsigned(value), self)

implVisitor(EvenIntVisitor)

proc expecting(self: EvenIntVisitor): string =
  "even int"

proc visitInt8(self: EvenIntVisitor, value: int8): self.Value = visitBody

proc visitInt16(self: EvenIntVisitor, value: int16): self.Value = visitBody

proc visitInt32(self: EvenIntVisitor, value: int32): self.Value = visitBody

proc visitInt64(self: EvenIntVisitor, value: int64): self.Value = visitBody

proc visitUint8(self: EvenIntVisitor, value: uint8): self.Value = visitBody

proc visitUint16(self: EvenIntVisitor, value: uint16): self.Value = visitBody

proc visitUint32(self: EvenIntVisitor, value: uint32): self.Value = visitBody

proc visitUint64(self: EvenIntVisitor, value: uint64): self.Value = visitBody
```

Let's check `EvenIntVisitor` by getting a sequence of `EvenInt` from json:
```nim
import deser_json

# To make an `EvenInt` deserializable, you need to write a `deserialize` procedure.
proc deserialize(Self: typedesc[EvenInt], deserializer: var auto): Self =
  mixin deserializeAny

  deserializer.deserializeAny(EvenIntVisitor())

echo seq[EvenInt].fromJson("[2, 4, 6, 8, 10]")
echo seq[EvenInt].fromJson("[1, 3, 5, 7, 9]")
```
Full code:
```nim
import deser, deser_json

type
  EvenInt = distinct int
  EvenIntVisitor = object

proc `$`(self: EvenInt): string = $self.int

# implVisitor requires that Visitor has a Value parameter. Value is your type.
template Value(visitor: EvenIntVisitor): type = EvenInt

# The body of the methods is not much different, so let's write a template and use it.
template visitBody: EvenInt {.dirty.} =
  if value mod 2 == 0:
    EvenInt(value)
  else:
    when value is SomeSignedInt:
      raiseInvalidType(initUnexpectedSigned(value), self)
    else:
      raiseInvalidType(initUnexpectedUnsigned(value), self)

implVisitor(EvenIntVisitor)

proc expecting(self: EvenIntVisitor): string =
  "even int"

proc visitInt8(self: EvenIntVisitor, value: int8): self.Value = visitBody

proc visitInt16(self: EvenIntVisitor, value: int16): self.Value = visitBody

proc visitInt32(self: EvenIntVisitor, value: int32): self.Value = visitBody

proc visitInt64(self: EvenIntVisitor, value: int64): self.Value = visitBody

proc visitUint8(self: EvenIntVisitor, value: uint8): self.Value = visitBody

proc visitUint16(self: EvenIntVisitor, value: uint16): self.Value = visitBody

proc visitUint32(self: EvenIntVisitor, value: uint32): self.Value = visitBody

proc visitUint64(self: EvenIntVisitor, value: uint64): self.Value = visitBody

# To make an `EvenInt` deserializable, you need to write a `deserialize` procedure.
proc deserialize(Self: typedesc[EvenInt], deserializer: var auto): Self =
  mixin deserializeAny

  deserializer.deserializeAny(EvenIntVisitor())

echo seq[EvenInt].fromJson("[2, 4, 6, 8, 10]")
# Error: unhandled exception: invalid type: integer `1`, expected: even int [InvalidType]
echo seq[EvenInt].fromJson("[1, 3, 5, 7, 9]")
```

# SeqAccess
To gain access to the elements of the sequence, the `Visitor` gets a `SeqAccess` object in the `visitSeq` method.

`SeqAccess` has the following methods:
```nim
proc nextElementSeed(self: var Self, seed: auto): Option[seed.Value]

proc nextElement[Value](self: var Self): Option[Value]

proc sizeHint(self: Self): Option[int]

iterator items[Value](self: var Self): Value
```

All methods except `nextElementSeed` are implemented by default using the [implSeqAccess](#implSeqAccess.t%2C%2Cstatic[bool]) template.

# MapAccess
To gain access to the elements of the map, the `Visitor` gets a `MapAccess` object in the `visitMap` method.

`MapAccess` has the following methods:
```nim
proc nextKeySeed(self: var Self, seed: auto): Option[seed.Value]

proc nextValueSeed(self: var Self, seed: auto): seed.Value

proc nextEntrySeed(self: var Self, kseed: auto, vseed: auto): Option[(kseed.Value, vseed.Value)]

proc nextKey[Key](self: var Self): Option[Key]

proc nextValue[Value](self: var Self): Value

proc nextEntry[Key, Value](self: var Self): Option[tuple[key: Key, value: Value]]

proc sizeHint[Self: Self](self: Self): Option[int] = none(int)

iterator keys[Key](self: var Self): Key

iterator pairs[Key, Value](self: var Self): (Key, Value)
```

All methods except `nextKeySeed` and `nextValueSeed` are implemented by default using the [implMapAccess](#implMapAccess.t%2C%2Cstatic[bool]) template.

# Deserializer

]##

import std/[
  options
]

from errors import
  raiseInvalidType,
  raiseInvalidValue,
  raiseDuplicateField,
  raiseInvalidLength,
  initUnexpectedBool,
  initUnexpectedUnsigned,
  initUnexpectedSigned,
  initUnexpectedFloat,
  initUnexpectedChar,
  initUnexpectedString,
  initUnexpectedBytes,
  initUnexpectedOption,
  initUnexpectedSeq,
  initUnexpectedMap

from deser/macroutils/generation/utils import
  maybePublic


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
    initUnexpectedBool,
    initUnexpectedSigned,
    initUnexpectedUnsigned,
    initUnexpectedFloat,
    initUnexpectedString,
    initUnexpectedBytes,
    initUnexpectedOption,
    initUnexpectedSeq,
    initUnexpectedMap,
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
    proc visitBool[Self: selfType](self: Self, value: bool): self.Value =
      raiseInvalidType(initUnexpectedBool(value), self)
      result = default(self.Value)

    proc visitInt8[Self: selfType](self: Self, value: int8): self.Value = self.visitInt64(value.int64)
    proc visitInt16[Self: selfType](self: Self, value: int16): self.Value = self.visitInt64(value.int64)
    proc visitInt32[Self: selfType](self: Self, value: int32): self.Value = self.visitInt64(value.int64)
    proc visitInt64[Self: selfType](self: Self, value: int64): self.Value =
      raiseInvalidType(initUnexpectedSigned(value), self)
      result = default(self.Value)

    proc visitUint8[Self: selfType](self: Self, value: uint8): self.Value = self.visitUint64(value.uint64)
    proc visitUint16[Self: selfType](self: Self, value: uint16): self.Value = self.visitUint64(value.uint64)
    proc visitUint32[Self: selfType](self: Self, value: uint32): self.Value = self.visitUint64(value.uint64)
    proc visitUint64[Self: selfType](self: Self, value: uint64): self.Value =
      raiseInvalidType(initUnexpectedUnsigned(value), self)
      result = default(self.Value)

    proc visitFloat32[Self: selfType](self: Self, value: float32): self.Value = self.visitFloat64(value.float64)
    proc visitFloat64[Self: selfType](self: Self, value: float64): self.Value =
      raiseInvalidType(initUnexpectedFloat(value), self)
      result = default(self.Value)

    proc visitChar[Self: selfType](self: Self, value: char): self.Value = self.visitString($value)
    proc visitString[Self: selfType](self: Self, value: sink string): self.Value =
      raiseInvalidType(initUnexpectedString(value), self)
      result = default(self.Value)

    proc visitBytes[Self: selfType](self: Self, value: openArray[byte]): self.Value =
      raiseInvalidType(initUnexpectedBytes(@value), self)
      result = default(self.Value)

    proc visitNone[Self: selfType](self: Self): self.Value =
      raiseInvalidType(initUnexpectedOption(), self)
      result = default(self.Value)

    proc visitSome[Self: selfType](self: Self, deserializer: var auto): self.Value =
      raiseInvalidType(initUnexpectedOption(), self)
      result = default(self.Value)

    proc visitSeq[Self: selfType](self: Self, sequence: var auto): self.Value =
      raiseInvalidType(initUnexpectedSeq(), self)
      result = default(self.Value)

    proc visitMap[Self: selfType](self: Self, map: var auto): self.Value =
      raiseInvalidType(initUnexpectedMap(), self)
      result = default(self.Value)

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
