##[

]##
{.experimental: "caseStmtMacros".}
import std/[
  options,
  strformat,
  sugar
]

import deser/des/[impls, helpers]

import deser/macroutils/matching

import token

type
  Deserializer* = ref object
    tokens: seq[Token]

  SeqVisitor = object
    de: Deserializer
    len: Option[uint]
    endToken: Token

  MapVisitor = object
    de: Deserializer
    len: Option[uint]
    endToken: Token


template endOfTokens =
  raise newException(AssertionDefect, "unexpected end of tokens")

template unexpected(token: Token) =
  raise newException(AssertionDefect, &"deserialization did not expect this token: {token.kind}")

func init*(Self: typedesc[Deserializer], tokens: openArray[Token]): Self =
  Self(tokens: @tokens)

func init*(Self: typedesc[SeqVisitor | MapVisitor], de: Deserializer, len: Option[uint], endToken: Token): Self =
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

proc nextTokenOpt*(self: Deserializer): Option[Token] =
  if self.tokens.len == 0:
    result = none Token
  else:
    result = some self.tokens[0]
    self.tokens = self.tokens[1..^1]

proc assertNextToken*(self: Deserializer, expected: Token) =
  let next = self.nextTokenOpt()

  if next.isSome:
    let tmp = next.unsafeGet
    if tmp != expected:
      raise newException(AssertionDefect, &"expected Token.{tmp.kind} but deserialization wants Token.{expected.kind}")
  else:
    raise newException(AssertionDefect, &"end of tokens byt deserialization wants Token.{expected.kind}"  )

proc nextToken*(self: Deserializer): Token =
  if self.tokens.len == 0:
    endOfTokens
  
  result = self.tokens[0]
  self.tokens = self.tokens[1..^1]

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

  case token.kind
  of Bool:
    visitor.visitBool(token.`bool`)
  of I8:
    visitor.visitInt8(token.i8)
  of I16:
    visitor.visitInt16(token.i16)
  of I32:
    visitor.visitInt32(token.i32)
  of I64:
    visitor.visitInt64(token.i64)
  of U8:
    visitor.visitUint8(token.u8)
  of U16:
    visitor.visitUint16(token.u16)
  of U32:
    visitor.visitUint32(token.u32)
  of U64:
    visitor.visitUint64(token.u64)
  of F32:
    visitor.visitFloat32(token.f32)
  of F64:
    visitor.visitFloat64(token.f64)
  of Char:
    visitor.visitChar(token.`char`)
  of String:
    visitor.visitString(token.`string`)
  of Bytes:
    visitor.visitBytes(token.bytes)
  of None:
    visitor.visitNone()
  of Some:
    visitor.visitSome(self)
  of Seq:
    self.visitSeq(token.seqLen, initSeqEndToken(), visitor)
  of Array:
    self.visitSeq(token.arrayLen, initArrayEndToken(), visitor)
  of Map:
    self.visitMap(token.mapLen, initMapEndToken(), visitor)
  of Struct:
    self.visitMap(some token.structLen, initStructEndToken(), visitor)
  else:
    unexpected token

proc deserializeOption*(self: var Deserializer, visitor: auto): visitor.Value =
  mixin
    visitNone,
    visitSome

  let token = self.peekToken()

  case token.kind:
  of None:
    discard self.nextToken()
    visitor.visitNone()
  of Some:
    discard self.nextToken()
    visitor.visitSome(self)
  else:
    self.deserializeAny(visitor)

proc deserializeStruct*(self: var Deserializer, name: static[string], fields: static[array], visitor: auto): visitor.Value =
  case self.peekToken():
  of Struct(structLen: @len):
    assertNextToken self, initStructToken(name, len)
    self.visitMap(some(fields.len), initStructEndToken(), visitor)
  of Map(mapLen: @len):
    self.nextToken()
    self.visitMap(some(fields.len), initMapEndToken(), visitor)
  else:
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
