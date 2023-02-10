import std/[
  options
]

import deser/ser/impls
from deser/ser/helpers import asAddr

import token


type
  Serializer* = object
    tokens*: seq[Token]


func init*(Self: typedesc[Serializer], tokens: openArray[Token]): Self =
  Self(tokens: @tokens)

proc assertSerTokens*(value: auto, tokens: openArray[Token]) =
  mixin serialize

  var ser = Serializer.init tokens
  value.serialize(ser)
  # check that `ser` passed by ref
  doAssert ser.tokens.len == 0,
    "The token sequence is not empty. There may have been a copy of the Serializer instead of passing by reference."

proc nextToken*(self: var Serializer): Option[Token] =
  if self.tokens.len == 0:
    result = none Token
  else:
    result = some self.tokens[0]
    self.tokens = self.tokens[1..^1]

proc remaining*(self: Serializer): int =
  self.tokens.len

proc assertNextToken*(ser: var Serializer, actual: Token) =
  let next = ser.nextToken()
  if next.isSome():
    let value = next.get()
    doAssert value == actual, "Expected " & $value & " but serialized as " & $actual
  else:
    raise newException(AssertionDefect, "Expected end of tokens, but " & $actual & " was serialized")

# Serializer impl
proc serializeBool*(self: var Serializer, v: bool) = assertNextToken self, initBoolToken(v)

proc serializeInt8*(self: var Serializer, v: int8) = assertNextToken self, initI8Token(v)

proc serializeInt16*(self: var Serializer, v: int16) = assertNextToken self, initI16Token(v)

proc serializeInt32*(self: var Serializer, v: int32) = assertNextToken self, initI32Token(v)

proc serializeInt64*(self: var Serializer, v: int64) = assertNextToken self, initI64Token(v)

proc serializeFloat32*(self: var Serializer, v: float32) = assertNextToken self, initF32Token(v)

proc serializeFloat64*(self: var Serializer, v: float32) = assertNextToken self, initF64Token(v)

proc serializeString*(self: var Serializer, v: openArray[char]) = assertNextToken self, initStringToken(v)

proc serializeChar*(self: var Serializer, v: char) = assertNextToken self, initCharToken(v)

proc serializeBytes*(self: var Serializer, v: openArray[byte]) = assertNextToken self, initBytesToken(@v)

proc serializeNone*(self: var Serializer) = assertNextToken self, initNoneToken()

proc serializeSome*(self: var Serializer, v: auto) = assertNextToken self, initSomeToken()

proc serializeEnum*(self: var Serializer, value: enum) = assertNextToken self, initEnumToken()

proc serializeArray*(self: var Serializer, len: static[int]): var Serializer =
  assertNextToken self, initArrayToken(some len)
  self

proc serializeSeq*(self: var Serializer, len: Option[int]): var Serializer =
  assertNextToken self, initSeqToken(len)
  self

proc serializeMap*(self: var Serializer, len: Option[int]): var Serializer =
  assertNextToken self, initMapToken(len)
  result = self

proc serializeStruct*(self: var Serializer, name: static[string]): var Serializer =
  assertNextToken self, initStructToken(name)
  result = self

# SerializeArray impl
proc serializeArrayElement*(self: var Serializer, v: auto) =
  mixin serialize

  v.serialize(self)

proc endArray*(self: var Serializer) = assertNextToken self, initArrayEndToken()


# SerializeSeq impl
proc serializeSeqElement*(self: var Serializer, v: auto) = 
  mixin serialize

  v.serialize(self)

proc endSeq*(self: var Serializer) = assertNextToken self, initSeqEndToken()

# SerializeMap impl
proc serializeMapKey*(self: var Serializer, key: auto) =
  mixin serialize

  key.serialize(self)

proc serializeMapValue*(self: var Serializer, v: auto) =
  mixin serialize

  v.serialize(self)

proc serializeMapEntry*(self: var Serializer, key: auto, value: auto) =
  self.serializeMapKey(key)
  self.serializeMapValue(value)

proc endMap*(self: var Serializer) = assertNextToken self, initMapEndToken()

# SerializeStruct impl
proc serializeStructField*(self: var Serializer, key: static[string], v: auto) =
  mixin serialize

  key.serialize(self)
  v.serialize(self)

proc endStruct*(self: var Serializer) = assertNextToken self, initStructEndToken()

proc collectSeq*(self: var Serializer, iter: auto) =
  when compiles(iter.len):
    let length = some iter.len
  else:
    let length = none int

  asAddr state, self.serializeSeq(length)

  for value in iter:
    state.serializeSeqElement(value)

  state.endSeq()

proc collectMap*(self: var Serializer, iter: auto) =
  when compiles(iter.len):
    let length = some iter.len
  else:
    let length = none int
  
  asAddr state, self.serializeMap(length)

  for key, value in iter:
    state.serializeMapEntry(key, value)
  
  state.endMap()
