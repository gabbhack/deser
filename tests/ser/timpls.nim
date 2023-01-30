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
  ser,
  test
]


suite "Serialize default impls":
  test "bool":
    assertSerTokens true, [initBoolToken(true)]
    assertSerTokens false, [initBoolToken(false)]
  
  test "int":
    assertSerTokens 0i8, [initI8Token(0)]
    assertSerTokens 0i16, [initI16Token(0)]
    assertSerTokens 0i32, [initI32Token(0)]
    assertSerTokens 0i64, [initI64Token(0)]
    assertSerTokens 0, [initI64Token(0)]
  
  test "float":
    assertSerTokens 0f32, [initF32Token(0.0)]
    assertSerTokens 0f64, [initF64Token(0.0)]
    assertSerTokens 0.0, [initF64Token(0.0)]
  
  test "char":
    assertSerTokens 'a', [initCharToken('a')]
  
  test "enum":
    type TestEnum = enum
      First
    
    assertSerTokens TestEnum.First, [initEnumToken()]
  
  test "bytes":
    assertSerTokens [byte(0)], [initBytesToken(@[byte(0)])]
    assertSerTokens @[byte(0)], [initBytesToken(@[byte(0)])]
  
  test "set":
    assertSerTokens {1, 2, 3}, [
      initSeqToken(some 3),
      initI64Token(1),
      initI64Token(2),
      initI64Token(3),
      initSeqEndToken()
    ]

  test "array":
    assertSerTokens [1, 2, 3], [
      initSeqToken(some 3),
      initI64Token(1),
      initI64Token(2),
      initI64Token(3),
      initSeqEndToken()
    ]

  test "seq":
    assertSerTokens @[1, 2, 3], [
      initSeqToken(some 3),
      initI64Token(1),
      initI64Token(2),
      initI64Token(3),
      initSeqEndToken()
    ]

  test "tuple":
    assertSerTokens (123, "123"), [
      initArrayToken(some 2),
      initI64Token(123),
      initStringToken("123"),
      initArrayEndToken()
    ]
  
  test "named tuple":
    assertSerTokens (id: 123), [
      initArrayToken(some 1),
      initI64Token(123),
      initArrayEndToken()
    ]
  
  test "option":
    assertSerTokens some 0, [
      initSomeToken()
    ]

    assertSerTokens none int, [
      initNoneToken()
    ]
  
  test "tables":
    # Table | TableRef | OrderedTable | OrderedTableRef
    assertSerTokens {1: "1"}.toTable, [
      initMapToken(some 1),
      initI64Token(1),
      initStringToken("1"),
      initMapEndToken()
    ]

    assertSerTokens {1: "1"}.newTable, [
      initMapToken(some 1),
      initI64Token(1),
      initStringToken("1"),
      initMapEndToken()
    ]

    assertSerTokens {1: "1"}.toOrderedTable, [
      initMapToken(some 1),
      initI64Token(1),
      initStringToken("1"),
      initMapEndToken()
    ]

    assertSerTokens {1: "1"}.newOrderedTable, [
      initMapToken(some 1),
      initI64Token(1),
      initStringToken("1"),
      initMapEndToken()
    ]
  
  test "sets":
    # HashSet | OrderedSet
    assertSerTokens [1].toHashSet, [
      initSeqToken(some 1),
      initI64Token(1),
      initSeqEndToken()
    ]

    assertSerTokens [1].toOrderedSet, [
      initSeqToken(some 1),
      initI64Token(1),
      initSeqEndToken()
    ]
