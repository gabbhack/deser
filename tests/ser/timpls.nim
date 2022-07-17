discard """
  matrix: "; -d:release; --gc:orc; -d:release --gc:orc"
"""
{.experimental: "views".}
import std/[unittest, options, tables, sets]
import deser
import deser/test


suite "Serialize default impls":
  test "bool":
    serTokens true, [Boolean(true)]
    serTokens false, [Boolean(false)]
  
  test "int":
    serTokens 0i8, [Integer(0)]
    serTokens 0i16, [Integer(0)]
    serTokens 0i32, [Integer(0)]
    serTokens 0i64, [Integer(0)]
  
  test "float":
    serTokens 0f32, [Float(0.0)]
    serTokens 0f64, [Float(0.0)]
  
  test "char":
    serTokens 'a', [Char('a')]
  
  test "enum":
    type TestEnum = enum
      First
    
    serTokens TestEnum.First, [String("First")]
  
  test "bytes":
    serTokens [byte(0)], [Bytes(@[byte(0)])]
    serTokens @[byte(0)], [Bytes(@[byte(0)])]
  
  test "set":
    serTokens {1,2,3}, [
      Seq(some 3),
      Integer(1),
      Integer(2),
      Integer(3),
      SeqEnd()
    ]
  
  test "seq map":
    serTokens {1: "1", 2: "2"}, [
      SeqMap(some 2),
      Integer(1),
      String("1"),
      Integer(2),
      String("2"),
      SeqMapEnd()
    ]

    serTokens @[(1, "1"), (2, "2")], [
      SeqMap(some 2),
      Integer(1),
      String("1"),
      Integer(2),
      String("2"),
      SeqMapEnd()
    ]
  
  test "array":
    serTokens [1, 2, 3], [
      Array(3),
      Integer(1),
      Integer(2),
      Integer(3),
      ArrayEnd()
    ]
  
  test "seq":
    serTokens @[1, 2, 3], [
      Seq(some 3),
      Integer(1),
      Integer(2),
      Integer(3),
      SeqEnd()
    ]
  
  test "unit tuple":
    type TestTuple = tuple[]

    serTokens default(TestTuple), [
      UnitTuple("TestTuple")
    ]
  
  test "tuple":
    type TestTuple = (int, string)

    serTokens default(TestTuple), [
      Tuple("TestTuple", 2),
      Integer(0),
      String(""),
      TupleEnd()
    ]
  
  test "named tuple":
    type TestTuple = tuple
      id: int
    
    serTokens default(TestTuple), [
      NamedTuple("TestTuple", 1),
      String("id"),
      Integer(0),
      NamedTupleEnd()
    ]
  
  test "unit struct":
    type TestObject = object

    serTokens default(TestObject), [
      UnitStruct("TestObject")
    ]
  
  test "option":
    serTokens some 0, [
      Some()
    ]

    serTokens none int, [
      None()
    ]
  
  test "tables":
    # Table | TableRef | OrderedTable | OrderedTableRef
    serTokens {1: "1"}.toTable, [
      Map(some 1),
      Integer(1),
      String("1"),
      MapEnd()
    ]

    serTokens {1: "1"}.newTable, [
      Map(some 1),
      Integer(1),
      String("1"),
      MapEnd()
    ]

    serTokens {1: "1"}.toOrderedTable, [
      Map(some 1),
      Integer(1),
      String("1"),
      MapEnd()
    ]

    serTokens {1: "1"}.newOrderedTable, [
      Map(some 1),
      Integer(1),
      String("1"),
      MapEnd()
    ]
  
  test "sets":
    # HashSet | OrderedSet
    serTokens [1].toHashSet, [
      Seq(some 1),
      Integer(1),
      SeqEnd()
    ]

    serTokens [1].toOrderedSet, [
      Seq(some 1),
      Integer(1),
      SeqEnd()
    ]
