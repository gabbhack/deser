{.experimental: "views".}

import std/[
  options
]

import ../des/[impls, helpers]

import token


type
  Deserializer* = object
    tokens: openArray[Token]
  
  SeqVisitor = object
    de: var Deserializer
    len: Option[int]
    endToken: Token

  MapVisitor = object
    de: var Deserializer
    len: Option[int]
    endToken: Token


template endOfTokens =
  raise newException(AssertionDefect, "unexpected end of tokens")


func init*(Self: typedesc[Deserializer], tokens: openArray[Token]): Self =
  Self(tokens: tokens.toOpenArray(tokens.low, tokens.high))


func init*(Self: typedesc[SeqVisitor], de: var Deserializer, len: Option[int], endToken: Token): Self =
  Self(de: de, len: len, endToken: endToken)


proc peekTokenOpt(self: Deserializer): Option[Token] =
  if self.tokens.len == 0:
    none Token
  else:
    some self.tokens[0]


proc peekToken(self: Deserializer): Token =
  if self.tokens.len == 0:
    endOfTokens

  self.tokens[0]


proc nextTokenOpt*(self: var Deserializer): Option[Token] =
  if self.tokens.len == 0:
    result = none Token
  else:
    result = some self.tokens[0]
    self.tokens = self.tokens[1..self.tokens.high]


proc assertNextToken*(self: var Deserializer, actual: Token) =
  let next = self.nextTokenOpt()
  if next.isSome():
    let value = next.unsafeGet()
    doAssert value == actual, "Expected " & $value & " but serialized as " & $actual
  else:
    doAssert Empty() == actual, "Expected end of tokens, but " & $actual & " was serialized"


proc nextToken(self: var Deserializer): Token =
  if self.tokens.len == 0:
    endOfTokens
  
  result = self.tokens[0]
  self.tokens = self.tokens[1..self.tokens.high]


proc remaining*(self: Deserializer): int = self.tokens.len


proc visitSeq(self: var Deserializer, len: Option[int], endToken: Token, visitor: auto): visitor.Value =
  mixin visitSeq

  result = visitor.visitSeq(SeqVisitor.init(self, len, endToken))

  assertNextToken self, endToken


proc visitMap(self: var Deserializer, len: Option[int], endToken: Token, visitor: auto): visitor.Value =
  mixin visitMap

  result = visitor.visitMap(MapVisitor.init(self, len, endToken))

  assertNextToken self, endToken


implDeserializer(Deserializer, public=false):
  self.deserializeAny(visitor)


proc deserializeAny(self: var Deserializer, visitor: auto) =
  mixin visitBool

  let token = self.nextToken()

  case token.kind
  of TokenKind.Boolean:
    visitor.visitBool(token.boolean)
  of TokenKind.Integer:
    discard
