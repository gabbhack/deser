discard """
  matrix: "; -d:release; --gc:orc; -d:release --gc:orc; --threads:on"
"""
{.experimental: "views".}
import std/[
  unittest,
  times,
  options,
  strformat
]

import deser/des
import deser/pragmas
import deser/test


proc fromTimestamp(deserializer: var auto): Time = fromUnix(deserialize(int64, deserializer))

proc raiseError(objName, fieldValue: auto) =
  raise newException(ValueError, &"Unknown field `{fieldValue}`")


type
  EmptyObject = object

  Object = object
    id: int

  GenericObject[T] = object
    id: T

  RefObject = ref object
    id: int
  
  ObjectWithRef = object
    id: ref int
  
  InheritObject = object of RootObj
    id: int
  
  CaseObject = object
    case kind: bool
    of true:
      yes: string
    else:
      discard
  
  UntaggedCaseObject = object
    case kind {.untagged.}: bool
    of true:
      yes: string
    of false:
      discard
  
  SkipObject = object
    alwaysSkipped {.skipped.}: int
    serializeSkipped {.skipDeserializing.}: int
  
  DeserializeWithObject = object
    date {.deserializeWith(fromTimestamp).}: Time
  
  RenameObject = object
    name {.renameDeserialize("fullname").}: string
    kek {.renamed("lol").}: string

  DefaultObject = object
    id {.defaultValue(123).}: int
  
  OnUnknownObject {.onUnknownKeys(raiseError).} = object

  RenameAllObject {.renameAll(SnakeCase).} = object
    text: string
    firstName: string

    case kind: bool
    of true:
      lastName: string
    else:
      discard


proc `==`*(x, y: ObjectWithRef): bool = x.id[] == y.id[]

proc `==`*(x, y: CaseObject | UntaggedCaseObject): bool =
  if x.kind == y.kind:
    if x.kind == true and y.kind == true:
      return x.yes == y.yes
    return true
  return false

proc `==`*(x, y: RenameAllObject): bool =
  if x.kind == y.kind and x.text == y.text and x.firstName == y.firstName:
    if x.kind == true and y.kind == true:
      return x.lastName == y.lastName
    return true
  return false

proc `$`*(x: ref): string = $x[]

makeDeserializable([
  EmptyObject,
  Object,
  GenericObject,
  RefObject,
  ObjectWithRef,
  InheritObject,
  CaseObject,
  UntaggedCaseObject,
  SkipObject,
  DeserializeWithObject,
  RenameObject,
  DefaultObject,
  OnUnknownObject,
  RenameAllObject
], public=true)


suite "makeDeserializable":
  test "EmptyObject":
    assertDesTokens EmptyObject(), [
      Struct("EmptyObject", 0),
      StructEnd()
    ]

  test "Object":
    assertDesTokens Object(id: 123), [
      Struct("Object", 1),
      String("id"),
      I64(123),
      StructEnd()
    ]
  
  test "GenericObject":
    assertDesTokens GenericObject[int](id: 123), [
      Struct("GenericObject", 1),
      String("id"),
      I64(123),
      StructEnd()
    ]
  
  test "RefObject":
    assertDesTokens RefObject(id: 123), [
      Struct("RefObject", 1),
      String("id"),
      I64(123),
      StructEnd()
    ]
  
  test "ObjectWithRef":
    let temp = new int
    temp[] = 123
    assertDesTokens ObjectWithRef(id: temp), [
      Struct("ObjectWithRef", 1),
      String("id"),
      I64(123),
      StructEnd()
    ]
  
  test "InheritObject":
    assertDesTokens InheritObject(id: 123), [
      Struct("InheritObject", 1),
      String("id"),
      I64(123),
      StructEnd()
    ]
  
  test "CaseObject":
    assertDesTokens CaseObject(kind: true), [
      Map(none int),
      String("kind"),
      Bool(true),
      String("yes"),
      String(""),
      MapEnd()
    ]

    assertDesTokens CaseObject(kind: false), [
      Map(none int),
      String("kind"),
      Bool(false),
      MapEnd()
    ]


  test "UntaggedCaseObject":
    assertDesTokens UntaggedCaseObject(kind: true), [
      Map(none int),
      String("yes"),
      String(""),
      MapEnd()
    ]

    assertDesTokens UntaggedCaseObject(kind: false), [
      Map(none int),
      MapEnd()
    ]

  test "SkipObject":
    assertDesTokens SkipObject(), [
      Struct("SkipObject", 0),
      StructEnd()
    ]
  
  test "DeserializeWithObject":
    assertDesTokens DeserializeWithObject(date: fromUnix(123)), [
      Struct("DeserializeWithObject", 1),
      String("date"),
      I64(123),
      StructEnd()
    ]
  
  test "RenameObject":
    assertDesTokens RenameObject(name: "123", kek: "123"), [
      Struct("RenameObject", 1),
      String("fullname"),
      String("123"),
      String("lol"),
      String("123"),
      StructEnd()
    ]
  
  test "DefaultObject":
    assertDesTokens DefaultObject(id: 123), [
      Struct("DefaultObject", 1),
      StructEnd()
    ]

  # crash on "-d:release --gc:refc"
  #[
    test "OnUnknownObject":
      expect(ValueError):
        assertDesTokens OnUnknownObject(), [
          Struct("OnUnknownObject", 1),
          String("test"),
          String("123"),
          StructEnd()
        ]
  ]#

  test "Ignore extra fields":
    assertDesTokens Object(id: 123), [
      Struct("Object", 1),
      String("id"),
      I64(123),
      String("text"),
      String("text"),
      StructEnd()
    ]
  
  test "RenameAllObject":
    assertDesTokens RenameAllObject(kind: true), [
      Struct("RenameAllObject", 2),
      String("text"),
      String(""),
      String("first_name"),
      String(""),
      String("kind"),
      Bool(true),
      String("last_name"),
      String(""),
      StructEnd()
    ]
