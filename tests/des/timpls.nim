discard """
  matrix: "; -d:release; --gc:orc; -d:release --gc:orc; --threads:on"
"""
import std/[
  unittest,
  options,
  tables,
  sets
]

import deser/[
  des,
  test
]


suite "Deserialize default impls":
  test "initBoolToken":
    assertDesTokens true, [initBoolToken(true)]
  
  test "int":
    assertDesTokens 0i8, [initI8Token(0)]
    assertDesTokens 0i16, [initI16Token(0)]
    assertDesTokens 0i32, [initI32Token(0)]
    assertDesTokens 0i64, [initI64Token(0)]
    assertDesTokens 0, [initI64Token(0)]
  
  test "float":
    assertDesTokens 0f32, [initF32Token(0.0)]
    assertDesTokens 0f64, [initF64Token(0.0)]
    assertDesTokens 0.0, [initF64Token(0.0)]
  
  test "char":
    assertDesTokens 'a', [initCharToken('a')]
  
  test "enum":
    type SimpleEnum = enum
      First = "first"
      Second
    
    assertDesTokens SimpleEnum.First, [initI8Token(0)]
    assertDesTokens SimpleEnum.First, [initI16Token(0)]
    assertDesTokens SimpleEnum.First, [initI32Token(0)]
    assertDesTokens SimpleEnum.First, [initI64Token(0)]

    assertDesTokens SimpleEnum.First, [initStringToken("first")]
    assertDesTokens SimpleEnum.Second, [initStringToken("Second")]
  
  test "bytes":
    assertDesTokens [byte(0)], [initBytesToken(@[byte(0)])]
    assertDesTokens @[byte(0)], [initBytesToken(@[byte(0)])]
  
  test "set":
    assertDesTokens {1,2,3}, [
      initSeqToken(some 3),
      initI64Token(1),
      initI64Token(2),
      initI64Token(3),
      initSeqEndToken()
    ]
  
  test "array":
    assertDesTokens [1,2,3], [
      initArrayToken(some 3),
      initI64Token(1),
      initI64Token(2),
      initI64Token(3),
      initArrayEndToken()
    ]
  
  test "seq":
    assertDesTokens @[1,2,3], [
      initSeqToken(some 3),
      initI64Token(1),
      initI64Token(2),
      initI64Token(3),
      initSeqEndToken()
    ]

  test "tuple":
    assertDesTokens (123, "123"), [
      initArrayToken(some 2),
      initI64Token(123),
      initStringToken("123"),
      initArrayEndToken()
    ]
  
  test "named tuple":
    assertDesTokens (id: 123), [
      initArrayToken(some 1),
      initI64Token(123),
      initArrayEndToken()
    ]
  
  test "option":
    assertDesTokens some 123, [
      initSomeToken(),
      initI64Token(123)
    ]
    assertDesTokens none int, [
      initNoneToken()
    ]
  
  test "tables":
    # Table | TableRef | OrderedTable | OrderedTableRef
    assertDesTokens {1: "1"}.toTable, [
      initMapToken(some 1),
      initI64Token(1),
      initStringToken("1"),
      initMapEndToken()
    ]

    assertDesTokens {1: "1"}.newTable, [
      initMapToken(some 1),
      initI64Token(1),
      initStringToken("1"),
      initMapEndToken()
    ]

    assertDesTokens {1: "1"}.toOrderedTable, [
      initMapToken(some 1),
      initI64Token(1),
      initStringToken("1"),
      initMapEndToken()
    ]

    assertDesTokens {1: "1"}.newOrderedTable, [
      initMapToken(some 1),
      initI64Token(1),
      initStringToken("1"),
      initMapEndToken()
    ]
  
  test "sets":
    # HashSet | OrderedSet
    assertDesTokens [1].toHashSet, [
      initSeqToken(some 1),
      initI64Token(1),
      initSeqEndToken()
    ]

    assertDesTokens [1].toOrderedSet, [
      initSeqToken(some 1),
      initI64Token(1),
      initSeqEndToken()
    ]
