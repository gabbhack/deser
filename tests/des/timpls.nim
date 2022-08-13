discard """
  matrix: "; -d:release; --gc:orc; -d:release --gc:orc; --threads:on"
"""
{.experimental: "views".}
import std/[unittest, options, tables, sets]
import deser
import deser/test


suite "Deserialize default impls":
  test "bool":
    assertDesTokens true, [Bool(true)]
  
  test "int":
    assertDesTokens 0i8, [I8(0)]
    assertDesTokens 0i16, [I16(0)]
    assertDesTokens 0i32, [I32(0)]
    assertDesTokens 0i64, [I64(0)]
    assertDesTokens 0, [I64(0)]
  
  test "float":
    assertDesTokens 0f32, [F32(0.0)]
    assertDesTokens 0f64, [F64(0.0)]
    assertDesTokens 0.0, [F64(0.0)]
  
  test "char":
    assertDesTokens 'a', [Char('a')]
  
  test "enum":
    type SimpleEnum = enum
      First = "first"
      Second
    
    assertDesTokens SimpleEnum.First, [I8(0)]
    assertDesTokens SimpleEnum.First, [I16(0)]
    assertDesTokens SimpleEnum.First, [I32(0)]
    assertDesTokens SimpleEnum.First, [I64(0)]

    assertDesTokens SimpleEnum.First, [String("first")]
    assertDesTokens SimpleEnum.Second, [String("Second")]
  
  test "bytes":
    assertDesTokens [byte(0)], [Bytes(@[byte(0)])]
    assertDesTokens @[byte(0)], [Bytes(@[byte(0)])]
  
  test "set":
    assertDesTokens {1,2,3}, [
      Seq(some 3),
      I64(1),
      I64(2),
      I64(3),
      SeqEnd()
    ]
  
  test "array":
    assertDesTokens [1,2,3], [
      Array(some 3),
      I64(1),
      I64(2),
      I64(3),
      ArrayEnd()
    ]
  
  test "seq":
    assertDesTokens @[1,2,3], [
      Seq(some 3),
      I64(1),
      I64(2),
      I64(3),
      SeqEnd()
    ]

  test "tuple":
    assertDesTokens (123, "123"), [
      Array(some 2),
      I64(123),
      String("123"),
      ArrayEnd()
    ]
  
  test "named tuple":
    assertDesTokens (id: 123), [
      Array(some 1),
      I64(123),
      ArrayEnd()
    ]
  
  test "option":
    assertDesTokens some 123, [
      Some(),
      I64(123)
    ]
    assertDesTokens none int, [
      None()
    ]
  
  test "tables":
    # Table | TableRef | OrderedTable | OrderedTableRef
    assertDesTokens {1: "1"}.toTable, [
      Map(some 1),
      I64(1),
      String("1"),
      MapEnd()
    ]

    assertDesTokens {1: "1"}.newTable, [
      Map(some 1),
      I64(1),
      String("1"),
      MapEnd()
    ]

    assertDesTokens {1: "1"}.toOrderedTable, [
      Map(some 1),
      I64(1),
      String("1"),
      MapEnd()
    ]

    assertDesTokens {1: "1"}.newOrderedTable, [
      Map(some 1),
      I64(1),
      String("1"),
      MapEnd()
    ]
  
  test "sets":
    # HashSet | OrderedSet
    assertDesTokens [1].toHashSet, [
      Seq(some 1),
      I64(1),
      SeqEnd()
    ]

    assertDesTokens [1].toOrderedSet, [
      Seq(some 1),
      I64(1),
      SeqEnd()
    ]
