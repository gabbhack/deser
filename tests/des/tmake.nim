discard """
  matrix: "; -d:release; --gc:orc; -d:release --gc:orc; --threads:on"
"""
{.experimental: "views".}
import std/[
  unittest,
  times,
  options,
  strformat,
  typetraits
]

import deser/[
  des,
  pragmas,
  test
]


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
  
  InheritObject {.renameAll: SnakeCase.} = object of RootObj
    id {.renamed: "i".}: int
  
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
    integer {.defaultValue.}: int
  
  OnUnknownObject {.onUnknownKeys(raiseError).} = object

  RenameAllObject {.renameAll(SnakeCase).} = object
    text: string
    firstName {.renameDeserialize("firstName").}: string

    case kind: bool
    of true:
      lastName: string
    else:
      discard

  DistinctObject = distinct Object
  DistinctToGenericObject = distinct GenericObject[int]
  DistinctGenericObject[T] = distinct GenericObject[T]

  ChildObject = object of InheritObject
    text: string
  
  ChildGenericObject[T] = object of InheritObject
    text: T

  ChildGenericToObject = object of ChildGenericObject[string]

  ChildRefObject = ref object of InheritObject
    text: string
  
  ChildOfRefObject = object of ChildRefObject

  InfectedChild = object of InheritObject
    firstName: string


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

proc `$`*(x: DistinctObject | DistinctToGenericObject | DistinctGenericObject): string = $distinctBase(typeof(x))(x)

proc `==`*(x, y: DistinctObject | DistinctToGenericObject | DistinctGenericObject): bool =
  distinctBase(typeof(x))(x) == distinctBase(typeof(y))(y)


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
  RenameAllObject,
  DistinctObject,
  DistinctToGenericObject,
  DistinctGenericObject,
  ChildObject,
  ChildGenericObject,
  ChildGenericToObject,
  ChildRefObject,
  ChildOfRefObject,
  InfectedChild
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
      String("i"),
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
    assertDesTokens DefaultObject(id: 123, integer: 0), [
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
      String("firstName"),
      String(""),
      String("kind"),
      Bool(true),
      String("last_name"),
      String(""),
      StructEnd()
    ]
  
  test "DistinctObject":
    assertDesTokens DistinctObject(Object(id: 123)), [
      Struct("istinctObject", 1),
      String("id"),
      I64(123),
      StructEnd()
    ]
  
  test "DistinctToGenericObject":
    assertDesTokens DistinctToGenericObject(GenericObject[int](id: 123)), [
      Struct("DistinctToGenericObject", 1),
      String("id"),
      I64(123),
      StructEnd()
    ]
  
  test "DistinctGenericObject":
    assertDesTokens DistinctGenericObject[int](GenericObject[int](id: 123)), [
      Struct("DistinctGenericObject", 1),
      String("id"),
      I64(123),
      StructEnd()
    ]

  test "ChildObject":
    assertDesTokens ChildObject(id: 123, text: "123"), [
      Struct("ChildObject", 2),
      String("i"),
      I64(123),
      String("text"),
      String("123"),
      StructEnd()
    ]
  
  test "ChildGenericObject":
    assertDesTokens ChildGenericObject[string](id: 123, text: "123"), [
      Struct("ChildGenericObject", 2),
      String("i"),
      I64(123),
      String("text"),
      String("123"),
      StructEnd()
    ]
  
  test "ChildRefObject":
    assertDesTokens ChildRefObject(id: 123, text: "123"), [
      Struct("ChildRefObject", 2),
      String("i"),
      I64(123),
      String("text"),
      String("123"),
      StructEnd()
    ]
  
  test "ChildGenericToObject":
    assertDesTokens ChildGenericToObject(id: 123, text: "123"), [
      Struct("ChildGenericToObject", 2),
      String("i"),
      I64(123),
      String("text"),
      String("123"),
      StructEnd()
    ]
  
  test "ChildOfRefObject":
    assertDesTokens ChildOfRefObject(id: 123, text: "123"), [
      Struct("ChildOfRefObject", 2),
      String("i"),
      I64(123),
      String("text"),
      String("123"),
      StructEnd()
    ]
  
  test "InfectedChild":
    assertDesTokens InfectedChild(id: 123, firstName: "123"), [
      Struct("InfectedChild", 2),
      String("i"),
      I64(123),
      String("first_name"),
      String("123"),
      StructEnd()
    ]
