import std/[strformat]

import ../error


type
  DeserializationError* = object of DeserError ## \
    ## Error during deserialization

  InvalidType* = object of DeserializationError ## \
    ## Raised when a `Deserialize` receives a type different from what it was expecting.
  
  InvalidValue* = object of DeserializationError ## \
    ## Raised when a `Deserialize` receives a value of the right type but that is wrong for some other reason.

  InvalidLength* = object of DeserializationError ## \
    ## Raised when deserializing a sequence or map and the input data contains too many or too few elements.

  UnknownField* = object of DeserializationError ## \
    ## Raised when a `Deserialize` enum type received a variant with an unrecognized name.

  MissingField* = object of DeserializationError ## \
    ## Raised when a `Deserialize` struct type expected to receive a required field with a particular name but that field was not present in the input.

  DuplicateField* = object of DeserializationError ## \
    ## Raised when a `Deserialize` struct type received more than one of the same field.
  
  UnknownUntaggedVariant* = object of DeserializationError ## \
    ## Raised when a `Deserialize` struct type cannot derive case variant.
  
  UnexpectedKind* = enum
    Bool,
    Unsigned,
    Signed,
    Float,
    Char,
    String,
    Bytes,
    Option,
    Seq,
    Map

  Unexpected* = object
    case kind*: UnexpectedKind
    of Bool:
      boolValue*: bool
    of Unsigned:
      unsignedValue*: uint64
    of Signed:
      signedValue*: int64
    of Float:
      floatValue*: float64
    of Char:
      charValue*: char
    of String:
      stringValue*: string
    of Bytes:
      bytesValue*: seq[byte]
    else:
      nil


when defined(release):
  {.push inline.}
func `$`*(self: Unexpected): string {.inline.} =
  case self.kind
  of Bool:
    &"boolean `{self.boolValue}`"
  of Unsigned:
    &"integer `{self.unsignedValue}`"
  of Signed:
    &"integer `{self.signedValue}`"
  of Float:
    &"floating point `{self.floatValue}`"
  of Char:
    &"character `{self.charValue}`"
  of String:
    &"string `{self.stringValue}`"
  of Bytes:
    "byte array"
  of Option:
    "Option value"
  of Seq:
    "sequence"
  of Map:
    "map"


func UnexpectedBool*(value: bool): auto = Unexpected(kind: Bool, boolValue: value)

func UnexpectedUnsigned*(value: uint64): auto = Unexpected(kind: Unsigned, unsignedValue: value)

func UnexpectedSigned*(value: int64): auto = Unexpected(kind: Signed, signedValue: value)

func UnexpectedFloat*(value: float64): auto = Unexpected(kind: Float, floatValue: value)

func UnexpectedChar*(value: char): auto = Unexpected(kind: Char, charValue: value)

func UnexpectedString*(value: sink string): auto = Unexpected(kind: String, stringValue: value)

func UnexpectedBytes*(value: sink seq[byte]): auto = Unexpected(kind: Bytes, bytesValue: value)

func UnexpectedOption*(): auto = Unexpected(kind: Option)

func UnexpectedSeq*(): auto = Unexpected(kind: Seq)

func UnexpectedMap*(): auto = Unexpected(kind: Map)
when defined(release):
  {.pop.}


{.push noinline, noreturn.}
proc raiseInvalidType*(unexp: Unexpected, exp: auto) =
  mixin expecting

  raise newException(InvalidType, &"invalid type: {$unexp}, expected: {exp.expecting()}")


proc raiseInvalidValue*(unexp: Unexpected, exp: auto) =
  mixin expecting

  raise newException(InvalidValue, &"invalid value: {$unexp}, expected: {exp.expecting()}")


proc raiseInvalidLength*(unexp: int, exp: auto) =
  raise newException(InvalidLength, &"invalid length: {$unexp}, expected: {$exp}")


proc raiseUnknownField*(unexp: sink string) =
  raise newException(UnknownField, &"unknown field {$unexp}, there are no fields")


proc raiseMissingField*(field: static[string]) =
  raise newException(MissingField, &"missing field `{field}`")


proc raiseDuplicateField*(field: static[string]) =
  raise newException(DuplicateField, &"duplicate field `{field}`")


proc raiseUnknownUntaggedVariant*(struct: static[string], field: static[string]) =
  raise newException(UnknownUntaggedVariant, &"not possible to derive value of case field `{field}` of struct `{struct}`")
{.pop.}
