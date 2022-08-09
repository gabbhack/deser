{.experimental: "views".}

import std/[
  options,
  strformat,
  sugar
]

import ../des/[impls, helpers]

import token, patty


type
  Deserializer* = object
    tokens: openArray[Token]
  
  SeqVisitor = object
    de: var Deserializer
    len: Option[uint]
    endToken: Token

  MapVisitor = object
    de: var Deserializer
    len: Option[uint]
    endToken: Token


template endOfTokens =
  raise newException(AssertionDefect, "unexpected end of tokens")


template unexpected(token: Token) =
  raise newException(AssertionDefect, &"deserialization did not expect this token: {token.kind}")


func init*(Self: typedesc[Deserializer], tokens: openArray[Token]): Self =
  Self(tokens: tokens.toOpenArray(tokens.low, tokens.high))


func init*(Self: typedesc[SeqVisitor | MapVisitor], de: var Deserializer, len: Option[uint], endToken: Token): Self =
  Self(de: de, len: len, endToken: endToken)


proc assertDesTokens*[T](value: T, tokens: openArray[Token]) =
  mixin
    deserialize

  var des = Deserializer.init tokens

  let res = T.deserialize(des)
  
  when T is ref:
    doAssert res[] == value[], &"The result is `{res}` but expected `{value}`"
  else:
    doAssert res == value, &"The result is `{res}` but expected `{value}`"

  doAssert des.tokens.len == 0,
    "The token sequence is not empty. There may have been a copy of the Deserializer instead of passing by reference."


proc peekTokenOpt*(self: Deserializer): Option[Token] =
  if self.tokens.len == 0:
    none Token
  else:
    some self.tokens[0]


proc peekToken*(self: Deserializer): Token =
  if self.tokens.len == 0:
    endOfTokens

  self.tokens[0]


proc nextTokenOpt*(self: var Deserializer): Option[Token] =
  if self.tokens.len == 0:
    result = none Token
  else:
    result = some self.tokens[0]
    self.tokens = self.tokens.toOpenArray(1, self.tokens.high)


proc assertNextToken*(self: var Deserializer, expected: Token) =
  let next = self.nextTokenOpt()

  if next.isSome:
    let tmp = next.unsafeGet
    if tmp != expected:
      raise newException(AssertionDefect, &"expected Token.{tmp.kind} but deserialization wants Token.{expected.kind}")
  else:
    raise newException(AssertionDefect, &"end of tokens byt deserialization wants Token.{expected.kind}"  )


proc nextToken*(self: var Deserializer): Token =
  if self.tokens.len == 0:
    endOfTokens
  
  result = self.tokens[0]
  self.tokens = self.tokens.toOpenArray(1, self.tokens.high)


proc remaining*(self: Deserializer): int = self.tokens.len


proc visitSeq*(self: var Deserializer, len: Option[int], endToken: Token, visitor: auto): visitor.Value =
  mixin visitSeq

  var sequence = SeqVisitor.init(self, len.map((x) => x.uint), endToken)

  result = visitor.visitSeq(sequence)

  assertNextToken self, endToken


proc visitMap*(self: var Deserializer, len: Option[int], endToken: Token, visitor: auto): visitor.Value =
  mixin visitMap

  var map = MapVisitor.init(self, len.map((x) => x.uint), endToken)

  result = visitor.visitMap(map)

  assertNextToken self, endToken


proc deserializeAny*(self: var Deserializer, visitor: auto): visitor.Value

# forward to deserializeAny
implDeserializer(Deserializer, public=true):
  self.deserializeAny(visitor)


proc deserializeAny*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin
    visitBool,
    visitInt8,
    visitInt16,
    visitInt32,
    visitInt64,
    visitUint8,
    visitUint16,
    visitUint32,
    visitUint64,
    visitFloat32,
    visitFloat64,
    visitChar,
    visitString,
    visitBytes,
    visitNone,
    visitSome

  let token = self.nextToken()

  match token:
    Bool(v):
      visitor.visitBool(v)
    I8(v):
      visitor.visitInt8(v)
    I16(v):
      visitor.visitInt16(v)
    I32(v):
      visitor.visitInt32(v)
    I64(v):
      visitor.visitInt64(v)
    U8(v):
      visitor.visitUint8(v)
    U16(v):
      visitor.visitUint16(v)
    U32(v):
      visitor.visitUint32(v)
    U64(v):
      visitor.visitUint64(v)
    F32(v):
      visitor.visitFloat32(v)
    F64(v):
      visitor.visitFloat64(v)
    Char(v):
      visitor.visitChar(v)
    String(v):
      visitor.visitString(v)
    Bytes(v):
      visitor.visitBytes(v)
    None:
      visitor.visitNone()
    Some:
      visitor.visitSome(self)
    Seq(length):
      self.visitSeq(length, SeqEnd(), visitor)
    Array(length):
      self.visitSeq(length, ArrayEnd(), visitor)
    Map(length):
      self.visitMap(length, MapEnd(), visitor)
    Struct(_, length):
      self.visitMap(some length, StructEnd(), visitor)
    _:
      unexpected token


proc deserializeOption*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin
    visitNone,
    visitSome
  
  match self.peekToken():
    None:
      discard self.nextToken()
      visitor.visitNone()
    Some:
      discard self.nextToken()
      visitor.visitSome(self)
    _:
      self.deserializeAny(visitor)


proc deserializeStruct*(self: var Deserializer, name: static[string], fields: static[array], visitor: auto): visitor.Value =
  match self.peekToken():
    Struct(_, len):
      assertNextToken self, Struct(name, len)
      self.visitMap(some(fields.len), StructEnd(), visitor)
    Map(len):
      self.nextToken()
      self.visitMap(some(fields.len), MapEnd(), visitor)
    _:
      self.deserializeAny(visitor)


implSeqAccess(SeqVisitor, public=true)


proc nextElementSeed*(self: var SeqVisitor, seed: auto): Option[seed.Value] =
  mixin
    deserialize
  
  if self.de.peekTokenOpt() == some(self.endToken):
    return none(seed.Value)
  
  self.len = self.len.map((x) => x - 1)

  result = some seed.deserialize(self.de)


proc sizeHint*(self: SeqVisitor): Option[int] = self.len.map((x) => x.int)


implMapAccess(MapVisitor, public=true)


proc nextKeySeed*(self: var MapVisitor, seed: auto): Option[seed.Value] =
  mixin
    deserialize
  
  if self.de.peekTokenOpt() == some(self.endToken):
    return none(seed.Value)
  
  self.len = self.len.map((x) => x - 1)
  
  result = some seed.deserialize(self.de)


proc nextValueSeed*(self: var MapVisitor, seed: auto): seed.Value =
  mixin
    deserialize

  seed.deserialize(self.de)


proc sizeHint*(self: MapVisitor): Option[int] = self.len.map((x) => x.int)
