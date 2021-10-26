import std/options

# TODO borrow test lib from https://github.com/serde-rs/serde/tree/master/serde_test
type
  TokenKind* {.pure.} = enum
    Boolean, Integer, Float, Char, String, Bytes, None, Some, UnitStruct, UnitTuple, Array, ArrayEnd, Seq, SeqEnd,
    Tuple, TupleEnd, NamedTuple, NamedTupleEnd, Map, MapEnd, Struct, StructEnd, SeqMap, SeqMapEnd, Empty

  Token* = object
    case kind*: TokenKind
    of TokenKind.Boolean:
      boolean*: bool    
    of TokenKind.Integer:
      integer*: int     
    of TokenKind.Float:  
      `float`*: float
    of TokenKind.Char:
      `char`*: char
    of TokenKind.String:
      str*: string
    of TokenKind.Bytes:
      bytes*: seq[byte]
    of TokenKind.None:
      nil
    of TokenKind.Some:
      nil
    of TokenKind.UnitStruct:
      unitStructName: string
    of TokenKind.UnitTuple:
      unitTupleName: string
    of TokenKind.Array:
      arrayLen*: int
    of TokenKind.ArrayEnd:
      nil
    of TokenKind.Seq:
      seqLen*: Option[int]
    of TokenKind.SeqEnd:
      nil
    of TokenKind.Tuple:
      tupleName*: string
      tupleLen*: int
    of TokenKind.TupleEnd:
      nil
    of TokenKind.NamedTuple:
      namedTupleName*: string
      namedTupleLen*: int
    of TokenKind.NamedTupleEnd:
      nil
    of TokenKind.Map:
        mapLen*: Option[int]
    of TokenKind.MapEnd:
      nil
    of TokenKind.Struct:
      structName*: string
    of TokenKind.StructEnd:
      nil
    of TokenKind.SeqMap:
      seqMapLen: Option[int]
    of TokenKind.SeqMapEnd:
      nil
    of TokenKind.Empty:
      nil

  
proc `==`*(a: Token; b: Token): bool {.used.} =
  if a.kind == b.kind:
    case a.kind
    of TokenKind.Boolean:
      return a.boolean == b.boolean
    of TokenKind.Integer:
      return a.integer == b.integer
    of TokenKind.Float:
      return a.float == b.float
    of TokenKind.Char:
      return a.char == b.char
    of TokenKind.String:
      return a.str == b.str
    of TokenKind.Bytes:
      return a.bytes == b.bytes
    of TokenKind.None:
      return true
    of TokenKind.Some:
      return true
    of TokenKind.UnitStruct:
      return a.unitStructName == b.unitStructName
    of TokenKind.UnitTuple:
      return a.unitTupleName == b.unitTupleName
    of TokenKind.Array:
      return a.arrayLen == b.arrayLen
    of TokenKind.ArrayEnd:
      return true
    of TokenKind.Seq:
      return a.seq_len == b.seq_len
    of TokenKind.SeqEnd:
      return true
    of TokenKind.Tuple:
      return a.tupleName == b.tupleName and a.tupleLen == b.tupleLen
    of TokenKind.TupleEnd:
      return true
    of TokenKind.NamedTuple:
      return a.namedTupleName == b.namedTupleName and
          a.namedTupleLen == b.namedTupleLen
    of TokenKind.NamedTupleEnd:
      return true
    of TokenKind.Map:
      return a.map_len == b.map_len
    of TokenKind.MapEnd:
      return true
    of TokenKind.Struct:
      return a.struct_name == b.struct_name
    of TokenKind.StructEnd:
      return true
    of TokenKind.SeqMap:
      return a.seqMapLen == b.seqMapLen
    of TokenKind.SeqMapEnd:
      return true
    of TokenKind.Empty:
      return true
  else:
    return false

proc Boolean*(boolean: bool): Token {.used.} =
  result = Token(kind: TokenKind.Boolean, boolean: boolean)

proc Integer*(integer: int): Token {.used.} =
  result = Token(kind: TokenKind.Integer, integer: integer)

proc Float*(float: float): Token {.used.} =
  result = Token(kind: TokenKind.Float, float: float)

proc Char*(char: char): Token {.used.} =
  result = Token(kind: TokenKind.Char, char: char)

proc String*(str: string): Token {.used.} =
  result = Token(kind: TokenKind.String, str: str)

proc Bytes*(bytes: seq[byte]): Token {.used.} =
  result = Token(kind: TokenKind.Bytes, bytes: bytes)

proc None*(): Token {.used.} =
  result = Token(kind: TokenKind.None)

proc Some*(): Token {.used.} =
  result = Token(kind: TokenKind.Some)

proc UnitStruct*(unitStructName: string): Token {.used.} =
  result = Token(kind: TokenKind.UnitStruct, unitStructName: unitStructName)

proc UnitTuple*(unitTupleName: string): Token {.used.} =
  result = Token(kind: TokenKind.UnitTuple, unitTupleName: unitTupleName)

proc Array*(arrayLen: int): Token {.used.} =
  result = Token(kind: TokenKind.Array, arrayLen: arrayLen)

proc ArrayEnd*(): Token {.used.} =
  result = Token(kind: TokenKind.ArrayEnd)

proc Seq*(seq_len: Option[int]): Token {.used.} =
  result = Token(kind: TokenKind.Seq, seq_len: seq_len)

proc SeqEnd*(): Token {.used.} =
  result = Token(kind: TokenKind.SeqEnd)

proc Tuple*(tupleName: string, tupleLen: int): Token {.used.} =
  result = Token(kind: TokenKind.Tuple, tupleName: tupleName, tupleLen: tupleLen)

proc TupleEnd*(): Token {.used.} =
  result = Token(kind: TokenKind.TupleEnd)

proc NamedTuple*(namedTupleName: string; namedTupleLen: int): Token {.used.} =
  result = Token(kind: TokenKind.NamedTuple, namedTupleName: namedTupleName,
                 namedTupleLen: namedTupleLen)

proc NamedTupleEnd*(): Token {.used.} =
  result = Token(kind: TokenKind.NamedTupleEnd)

proc Map*(map_len: Option[int]): Token {.used.} =
  result = Token(kind: TokenKind.Map, map_len: map_len)

proc MapEnd*(): Token {.used.} =
  result = Token(kind: TokenKind.MapEnd)

proc Struct*(struct_name: string): Token {.used.} =
  result = Token(kind: TokenKind.Struct, struct_name: struct_name)

proc StructEnd*(): Token {.used.} =
  result = Token(kind: TokenKind.StructEnd)

proc SeqMap*(seqMapLen: Option[int]): Token {.used.} =
  result = Token(kind: TokenKind.SeqMap, seqMapLen: seqMapLen)

proc SeqMapEnd*(): Token {.used.} =
  result = Token(kind: TokenKind.SeqMapEnd)

proc Empty*(): Token {.used.} =
  result = Token(kind: TokenKind.Empty)
