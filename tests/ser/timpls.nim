discard """
  matrix: "; -d:release; --gc:orc; -d:release --gc:orc; --threads:on"
"""
{.experimental: "views".}
import std/[unittest, options, tables, sets]
import deser
import deser/test


suite "Serialize default impls":
  test "bool":
    assertSerTokens true, [Bool(true)]
    assertSerTokens false, [Bool(false)]
  
  test "int":
    assertSerTokens 0i8, [I8(0)]
    assertSerTokens 0i16, [I16(0)]
    assertSerTokens 0i32, [I32(0)]
    assertSerTokens 0i64, [I64(0)]
    assertSerTokens 0, [I64(0)]
  
  test "float":
    assertSerTokens 0f32, [F32(0.0)]
    assertSerTokens 0f64, [F64(0.0)]
    assertSerTokens 0.0, [F64(0.0)]
  
  test "char":
    assertSerTokens 'a', [Char('a')]
  
  test "enum":
    type TestEnum = enum
      First
    
    assertSerTokens TestEnum.First, [Enum()]
  
  test "bytes":
    assertSerTokens [byte(0)], [Bytes(@[byte(0)])]
    assertSerTokens @[byte(0)], [Bytes(@[byte(0)])]
  
  test "set":
    assertSerTokens {1, 2, 3}, [
      Seq(some 3),
      I64(1),
      I64(2),
      I64(3),
      SeqEnd()
    ]

  test "array":
    assertSerTokens [1, 2, 3], [
      Seq(some 3),
      I64(1),
      I64(2),
      I64(3),
      SeqEnd()
    ]

  test "seq":
    assertSerTokens @[1, 2, 3], [
      Seq(some 3),
      I64(1),
      I64(2),
      I64(3),
      SeqEnd()
    ]

  test "tuple":
    assertSerTokens (123, "123"), [
      Array(some 2),
      I64(123),
      String("123"),
      ArrayEnd()
    ]
  
  test "named tuple":
    assertSerTokens (id: 123), [
      Array(some 1),
      I64(123),
      ArrayEnd()
    ]
  
  test "option":
    assertSerTokens some 0, [
      Some()
    ]

    assertSerTokens none int, [
      None()
    ]
  
  test "tables":
    # Table | TableRef | OrderedTable | OrderedTableRef
    assertSerTokens {1: "1"}.toTable, [
      Map(some 1),
      I64(1),
      String("1"),
      MapEnd()
    ]

    assertSerTokens {1: "1"}.newTable, [
      Map(some 1),
      I64(1),
      String("1"),
      MapEnd()
    ]

    assertSerTokens {1: "1"}.toOrderedTable, [
      Map(some 1),
      I64(1),
      String("1"),
      MapEnd()
    ]

    assertSerTokens {1: "1"}.newOrderedTable, [
      Map(some 1),
      I64(1),
      String("1"),
      MapEnd()
    ]
  
  test "sets":
    # HashSet | OrderedSet
    assertSerTokens [1].toHashSet, [
      Seq(some 1),
      I64(1),
      SeqEnd()
    ]

    assertSerTokens [1].toOrderedSet, [
      Seq(some 1),
      I64(1),
      SeqEnd()
    ]
