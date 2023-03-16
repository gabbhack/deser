discard """
  matrix: "; -d:release; --gc:orc; -d:release --gc:orc; --threads:on"
"""
import std/[
  times,
  options
]

import deser

import deser/test

type
  UnixTimeObject = object
    field {.deserWith(UnixTimeFormat).}: Time

  DateTimeFormatObject = object
    field {.deserWith(DateTimeWith(format: "yyyy-MM-dd")).}: DateTime


template types: untyped = [
  UnixTimeObject,
  DateTimeFormatObject
]

template run(obj, tokens: untyped) =
  assertSerTokens obj, tokens
  assertDesTokens obj, tokens

makeSerializable(types)
makeDeserializable(types)

run UnixTimeObject(field: fromUnix(123)), [
  initMapToken(none int),
  initStringToken("field"),
  initI64Token(123),
  initMapEndToken()
]

run DateTimeFormatObject(field: parse("2000-01-01", "yyyy-MM-dd")), [
  initMapToken(none int),
  initStringToken("field"),
  initStringToken("2000-01-01"),
  initMapEndToken()
]
