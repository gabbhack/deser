import std/strformat


type
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


func `$`*(self: Unexpected): string {.noinit, inline.} =
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


func UnexpectedBool*(value: bool): auto {.noinit, inline.} = Unexpected(kind: Bool, boolValue: value)

func UnexpectedUnsigned*(value: uint64): auto {.noinit, inline.} = Unexpected(kind: Unsigned, unsignedValue: value)

func UnexpectedSigned*(value: int64): auto {.noinit, inline.} = Unexpected(kind: Signed, signedValue: value)

func UnexpectedFloat*(value: float64): auto {.noinit, inline.} = Unexpected(kind: Float, floatValue: value)

func UnexpectedChar*(value: char): auto {.noinit, inline.} = Unexpected(kind: Char, charValue: value)

func UnexpectedString*(value: string): auto {.noinit, inline.} = Unexpected(kind: String, stringValue: value)

func UnexpectedBytes*(value: seq[byte]): auto {.noinit, inline.} = Unexpected(kind: Bytes, bytesValue: value)

func UnexpectedOption*(): auto {.noinit, inline.} = Unexpected(kind: Option)

func UnexpectedSeq*(): auto {.noinit, inline.} = Unexpected(kind: Seq)

func UnexpectedMap*(): auto {.noinit, inline.} = Unexpected(kind: Map)
