import std/[
  options
]

import patty


variantp Token:
  Bool(bool: bool)
  I8(i8: int8)
  I16(i16: int16)
  I32(i32: int32)
  I64(i64: int64)
  U8(u8: uint8)
  U16(u16: uint16)
  U32(u32: uint32)
  U64(u64: uint64)
  F32(f32: float32)
  F64(f64: float64)
  Char(char: char)
  String(string: string)
  Bytes(bytes: seq[byte])
  None
  Some
  Seq(seqLen: Option[int])
  SeqEnd
  Array(arrayLen: Option[int])
  ArrayEnd
  Map(mapLen: Option[int])
  MapEnd
  Struct(structName: string, structLen: int)
  StructEnd
  Enum
