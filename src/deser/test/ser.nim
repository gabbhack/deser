import std/options

import ../ser/impls
import token

type
  Serializer* = object
    tokens: seq[Token]


proc serTokens*[T](value: T, tokens: openArray[Token]) =
  var ser = Serializer(tokens: @tokens)
  value.serialize(ser)
  # check that `ser` passed by ref
  doAssert ser.tokens.len == 0,
    "The token sequence is not empty. There may have been a copy of the Serializer instead of passing by reference."


proc nextToken*(self: var Serializer): Option[Token] =
  if self.tokens.len == 0:
    result = none Token
  else:
    result = some self.tokens[0]
    self.tokens = self.tokens[1..self.tokens.high]


proc remaining*(self: Serializer): int = self.tokens.len

proc assertNextToken*(ser: var Serializer, actual: Token) =
  let next = ser.nextToken()
  if next.isSome():
    let value = next.unsafeGet()
    doAssert value == actual, "Expected " & $value & " but serialized as " & $actual
  else:
    doAssert Empty() == actual, "Expected end of tokens, but " & $actual & " was serialized"

# Serializer impl
proc serializeBool*(self: var Serializer, v: bool) = assertNextToken self, Boolean(v)

proc serializeInt*(self: var Serializer, v: SomeInteger) = assertNextToken self, Integer(int(v))

proc serializeFloat*(self: var Serializer, v: SomeFloat) = assertNextToken self, Float(float(v))

proc serializeString*(self: var Serializer, v: string) = assertNextToken self, String(v)

proc serializeChar*(self: var Serializer, v: char) = assertNextToken self, Char(v)

proc serializeBytes*(self: var Serializer, v: openArray[byte]) = assertNextToken self, Bytes(@v)

proc serializeNone*(self: var Serializer) = assertNextToken self, None()

proc serializeSome*[T](self: var Serializer, v: T) = assertNextToken self, Some()

proc serializeUnitStruct*(self: var Serializer, name: static[string]) = assertNextToken self, UnitStruct(name)

proc serializeUnitTuple*(self: var Serializer, name: static[string]) = assertNextToken self, UnitTuple(name)

proc serializeArray*(self: var Serializer, len: static[int]): var Serializer =
  assertNextToken self, Array(len)
  result = self


proc serializeSeq*(self: var Serializer, len: Option[int]): var Serializer =
  assertNextToken self, Seq(len)
  result = self


proc serializeTuple*(self: var Serializer, name: static[string], len: static[int]): var Serializer =
  assertNextToken self, Tuple(name, len)
  result = self


proc serializeNamedTuple*(self: var Serializer, name: static[string], len: static[int]): var Serializer =
  assertNextToken self, NamedTuple(name, len)
  result = self


proc serializeMap*(self: var Serializer, len: Option[int]): var Serializer =
  assertNextToken self, Map(len)
  result = self


proc serializeStruct*(self: var Serializer, name: static[string]): var Serializer =
  assertNextToken self, Struct(name)
  result = self


proc serializeSeqMap*(self: var Serializer, len: Option[int]): var Serializer =
  assertNextToken self, SeqMap(len)
  result = self


# SerializeArray impl
proc serializeArrayElement*[T](self: var Serializer, v: T) = v.serialize(self)

proc endArray*(self: var Serializer) = assertNextToken self, ArrayEnd()

# SerializeSeq impl
proc serializeSeqElement*[T](self: var Serializer, v: T) = v.serialize(self)

proc endSeq*(self: var Serializer) = assertNextToken self, SeqEnd()

# SerializeTuple impl
proc serializeTupleElement*[T](self: var Serializer, v: T) = v.serialize(self)

proc endTuple*(self: var Serializer) = assertNextToken self, TupleEnd()

# SerializeNamedTuple impl
proc serializeNamedTupleField*[T](self: var Serializer, key: static[string], v: T) =
  key.serialize(self)
  v.serialize(self)


proc endNamedTuple*(self: var Serializer) = assertNextToken self, NamedTupleEnd()

# SerializeMap impl
proc serializeMapKey*[T](self: var Serializer, key: T) = key.serialize(self)

proc serializeMapValue*[T](self: var Serializer, v: T) = v.serialize(self)

proc endMap*(self: var Serializer) = assertNextToken self, MapEnd()

# SerializeStruct impl
proc serializeStructField*[T](self: var Serializer, key: static[string], v: T) =
  key.serialize(self)
  v.serialize(self)


proc endStruct*(self: var Serializer) = assertNextToken self, StructEnd()

# SerializeSeqMap impl
proc serializeSeqMapKey*[T](self: var Serializer, key: T) = key.serialize(self)

proc serializeSeqMapValue*[T](self: var Serializer, v: T) = v.serialize(self)

proc endSeqMap*(self: var Serializer) = assertNextToken self, SeqMapEnd()
