{.experimental: "caseStmtMacros".}
import std/[
  options,
  unicode
]

import deser/macroutils/matching
import deser/des/errors


type
  ContentType* = enum
    Bool
    U8, U16, U32, U64
    I8, I16, I32, I64
    F32, F64
    Char
    String
    Bytes
    None, Some
    Seq
    Map

  Content* = object
    case kind*: ContentType
    of Bool:
      `bool`*: bool
    of I8:
      i8*: int8
    of I16:
      i16*: int16
    of I32:
      i32*: int32
    of I64:
      i64*: int64
    of U8:
      u8*: uint8
    of U16:
      u16*: uint16
    of U32:
      u32*: uint32
    of U64:
      u64*: uint64
    of F32:
      f32*: float32
    of F64:
      f64*: float64
    of Char:
      `char`*: char
    of String:
      `string`*: string
    of Bytes:
      bytes*: seq[byte]
    of None:
      discard
    of Some:
      some*: ref Content
    of Seq:
      `seq`*: seq[Content]
    of Map:
      map*: seq[(Content, Content)]

when defined(release):
  {.push inline.}

proc initContent*(value: auto): Content =
  when value is bool:
    Content(kind: Bool, bool: value)
  elif value is int8:
    Content(kind: I8, i8: value)
  elif value is int16:
    Content(kind: I16, i16: value)
  elif value is int32:
    Content(kind: I32, i32: value)
  elif value is (int64 or int):
    Content(kind: I64, i64: value.int64)
  elif value is uint8:
    Content(kind: U8, u8: value)
  elif value is uint16:
    Content(kind: U16, u16: value)
  elif value is uint32:
    Content(kind: U32, u32: value)
  elif value is (uint64 or uint):
    Content(kind: U64, u64: value.uint64)
  elif value is float32:
    Content(kind: F32, f32: value)
  elif value is (float64 or float):
    Content(kind: F64, f64: value)
  elif value is char:
    Content(kind: Char, char: value)
  elif value is string:
    Content(kind: String, string: value)
  elif value is seq[byte]:
    Content(kind: Bytes, bytes: value)
  elif value is seq[Content]:
    Content(kind: Seq, seq: value)
  elif value is seq[(Content, Content)]:
    Content(kind: Map, map: value)
  else:
    {.error: "Unsupported type " & $typeof(value).}

proc initSomeContent*(value: Content): Content =
  let content = new Content
  content[] = value

  Content(kind: Some, some: content)

proc initNoneContent*(): Content =
  Content(kind: None)

proc isSome(self: Content): bool = self.kind == Some

proc isNone(self: Content): bool = self.kind == None

proc asStr*(self: Content): Option[string] =
  case self
  of String(string: @string):
    some(string)
  of Bytes(bytes: @bytes):
    var tempString = newStringOfCap(bytes.len)

    for i in bytes:
      tempString.add i.char

    if validateUtf8(tempString) == -1:
      some(tempString)
    else:
      none(string)
  else:
    none(string)

proc unexpected*(self: Content): Unexpected =
  case self
  of Bool(bool: @bool):
    return initUnexpectedBool(bool)
  of U8(u8: @u8):
    return initUnexpectedUnsigned(u8.uint64)
  of U16(u16: @u16):
    return initUnexpectedUnsigned(u16.uint64)
  of U32(u32: @u32):
    return initUnexpectedUnsigned(u32.uint64)
  of U64(u64: @u64):
    return initUnexpectedUnsigned(u64.uint64)
  of I8(i8: @i8):
    return initUnexpectedSigned(i8.int64)
  of I16(i16: @i16):
    return initUnexpectedSigned(i16.int64)
  of I32(i32: @i32):
    return initUnexpectedSigned(i32.int64)
  of I64(i64: @i64):
    return initUnexpectedSigned(i64.int64)
  of F32(f32: @f32):
    return initUnexpectedFloat(f32.float64)
  of F64(f64: @f64):
    return initUnexpectedFloat(f64.float64)
  of Char(char: @char):
    return initUnexpectedChar(char)
  of String(string: @string):
    return initUnexpectedString(string)
  of Bytes(bytes: @bytes):
    return initUnexpectedBytes(bytes)
  of None():
    return initUnexpectedOption()
  of Some():
    return initUnexpectedOption()
  of Seq():
    return initUnexpectedSeq()
  of Map():
    return initUnexpectedMap()

when defined(release):
  {.pop.}
