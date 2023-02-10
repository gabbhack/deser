import std/[
  options
]

type
  TokenKind* = enum
    Bool,
    I8, I16, I32, I64,
    U8, U16, U32, U64,
    F32, F64,
    Char, String, Bytes,
    None, Some,
    Seq, SeqEnd,
    Array, ArrayEnd,
    Map, MapEnd,
    Struct, StructEnd,
    Enum

  Token* = object
    case kind*: TokenKind
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
      discard
    of Seq:
      seqLen*: Option[int]
    of SeqEnd:
      discard
    of Array:
      arrayLen*: Option[int]
    of ArrayEnd:
      discard
    of Map:
      mapLen*: Option[int]
    of MapEnd:
      discard
    of Struct:
      structName*: string
      structLen*: int
    of StructEnd:
      discard
    of Enum:
      discard

proc initBoolToken*(value: bool): Token =
  Token(kind: Bool, `bool`: value)

proc initI8Token*(value: int8): Token =
  Token(kind: I8, i8: value)

proc initI16Token*(value: int16): Token =
  Token(kind: I16, i16: value)

proc initI32Token*(value: int32): Token =
  Token(kind: I32, i32: value)

proc initI64Token*(value: int64): Token =
  Token(kind: I64, i64: value)

proc initU8Token*(value: uint8): Token =
  Token(kind: U8, u8: value)

proc initU16Token*(value: uint16): Token =
  Token(kind: U16, u16: value)

proc initU32Token*(value: uint32): Token =
  Token(kind: U32, u32: value)

proc initU64Token*(value: uint64): Token =
  Token(kind: U64, u64: value)

proc initF32Token*(value: float32): Token =
  Token(kind: F32, f32: value)

proc initF64Token*(value: float64): Token =
  Token(kind: F64, f64: value)

proc initCharToken*(value: char): Token =
  Token(kind: Char, `char`: value)

proc initStringToken*(value: openArray[char]): Token =
  var temp = newStringOfCap(value.len)
  for i in value:
    temp.add i
  Token(kind: String, `string`: temp)

proc initBytesToken*(value: seq[byte]): Token =
  Token(kind: Bytes, bytes: value)

proc initNoneToken*(): Token =
  Token(kind: None)

proc initSomeToken*(): Token =
  Token(kind: Some)

proc initSeqToken*(len: Option[int]): Token =
  Token(kind: Seq, seqLen: len)

proc initSeqEndToken*(): Token =
  Token(kind: SeqEnd)

proc initArrayToken*(len: Option[int]): Token =
  Token(kind: Array, arrayLen: len)

proc initArrayEndToken*(): Token =
  Token(kind: ArrayEnd)

proc initMapToken*(len: Option[int]): Token =
  Token(kind: Map, mapLen: len)

proc initMapEndToken*(): Token =
  Token(kind: MapEnd)

proc initStructToken*(name: string, len: int): Token =
  Token(kind: Struct, structName: name, structLen: len)

proc initStructEndToken*(): Token =
  Token(kind: StructEnd)

proc initEnumToken*(): Token =
  Token(kind: Enum)

proc `==`*(lhs, rhs: Token): bool =
  if lhs.kind == rhs.kind:
    case lhs.kind
    of Bool:
      lhs.`bool` == rhs.`bool`
    of I8:
      lhs.i8 == rhs.i8
    of I16:
      lhs.i16 == rhs.i16
    of I32:
      lhs.i32 == rhs.i32
    of I64:
      lhs.i64 == rhs.i64
    of U8:
      lhs.u8 == rhs.u8
    of U16:
      lhs.u16 == rhs.u16
    of U32:
      lhs.u32 == rhs.u32
    of U64:
      lhs.u64 == rhs.u64
    of F32:
      lhs.f32 == rhs.f32
    of F64:
      lhs.f64 == rhs.f64
    of Char:
      lhs.`char` == rhs.`char`
    of String:
      lhs.`string` == rhs.`string`
    of Bytes:
      lhs.bytes == rhs.bytes
    of None:
      true
    of Some:
      true
    of Seq:
      lhs.seqLen == rhs.seqLen
    of SeqEnd:
      true
    of Array:
      lhs.arrayLen == rhs.arrayLen
    of ArrayEnd:
      true
    of Map:
      lhs.mapLen == rhs.mapLen
    of MapEnd:
      true
    of Struct:
      lhs.structName == rhs.structName and lhs.structLen == rhs.structLen
    of StructEnd:
      true
    of Enum:
      true
  else:
    false