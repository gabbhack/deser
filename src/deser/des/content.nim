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
