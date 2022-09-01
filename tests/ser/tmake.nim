discard """
  matrix: "; -d:release; --gc:orc; -d:release --gc:orc; --threads:on"
"""
{.experimental: "views".}
import std/[
  unittest,
  options,
  times
]

import deser/[
  ser,
  pragmas,
  test
]


proc toTimestamp[Serializer](date: DateTime, serializer: var Serializer) = date.toTime.toUnix.serialize(serializer)


type
  Object = object
    id: int

  GenericObject[T] = object
    id: T
  
  ObjectWithRef = object
    id: ref int
  
  RefObject = ref object
    id: int
  
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
    else:
      discard
  
  SkipIfObject = object
    alwaysSkipped {.skipped.}: int
    serializeSkipped {.skipSerializing.}: int
    text {.skipSerializeIf(isNone).}: Option[string]
  
  SerializeWithObject = object
    date {.serializeWith(toTimestamp).}: DateTime
  
  RenameObject = object
    name {.renameSerialize("fullname").}: string
  
  RenameAllObject {.renameAll(SnakeCase).} = object
    text: string
    firstName {.renameSerialize("firstName").}: string

    case kind: bool
    of true:
      lastName: string
    else:
      discard
  
  DistinctObject {.borrow: `.`.} = distinct Object
  DistinctToGenericObject {.borrow: `.`.} = distinct GenericObject[int]
  DistinctGenericObject[T] {.borrow: `.`.} = distinct GenericObject[T]

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


makeSerializable([
  Object,
  GenericObject,
  ObjectWithRef,
  RefObject,
  InheritObject,
  CaseObject,
  UntaggedCaseObject,
  SkipIfObject,
  SerializeWithObject,
  RenameObject,
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


suite "makeSerializable":
  test "simple":
    assertSerTokens Object(id: 123), [
      Map(none int),
      String("id"),
      I64(123),
      MapEnd()
    ]
  
  test "generic":
    assertSerTokens GenericObject[int](id: 123), [
      Map(none int),
      String("id"),
      I64(123),
      MapEnd()
    ]
  
  test "with ref":
    let refInt = new int
    refInt[] = 123
    assertSerTokens ObjectWithRef(id: refInt), [
      Map(none int),
      String("id"),
      I64(123),
      MapEnd()
    ]
  
  test "ref":
    assertSerTokens RefObject(id: 123), [
      Map(none int),
      String("id"),
      I64(123),
      MapEnd()
    ]
  
  test "inherit":
    assertSerTokens InheritObject(id: 123), [
      Map(none int),
      String("i"),
      I64(123),
      MapEnd()
    ]
  
  test "case":
    assertSerTokens CaseObject(kind: true, yes: "yes"), [
      Map(none int),
      String("kind"),
      Bool(true),
      String("yes"),
      String("yes"),
      MapEnd()
    ]

    assertSerTokens CaseObject(kind: false), [
      Map(none int),
      String("kind"),
      Bool(false),
      MapEnd()
    ]
  
  test "untagged case":
    assertSerTokens UntaggedCaseObject(kind: true, yes: "yes"), [
      Map(none int),
      String("yes"),
      String("yes"),
      MapEnd()
    ]

    assertSerTokens UntaggedCaseObject(kind: false), [
      Map(none int),
      MapEnd()
    ]
  
  test "skipSerializeIf":
    assertSerTokens SkipIfObject(text: some "text"), [
      Map(none int),
      String("text"),
      Some(),
      MapEnd()
    ]

    assertSerTokens SkipIfObject(text: none string), [
      Map(none int),
      MapEnd()
    ]
  
  test "serializeWith":
    let date = now()
    assertSerTokens SerializeWithObject(date: date), [
      Map(none int),
      String("date"),
      I64(int(date.toTime.toUnix)),
      MapEnd()
    ]
  
  test "renameSerialize":
    assertSerTokens RenameObject(name: "Name"), [
      Map(none int),
      String("fullname"),
      String("Name"),
      MapEnd()
    ]
  
  test "RenameAllObject":
    assertSerTokens RenameAllObject(kind: true), [
      Map(none int),
      String("text"),
      String(""),
      String("firstName"),
      String(""),
      String("kind"),
      Bool(true),
      String("last_name"),
      String(""),
      MapEnd()
    ]
  
  test "DistinctObject":
    assertSerTokens DistinctObject(Object(id: 123)), [
      Map(none int),
      String("id"),
      I64(123),
      MapEnd()
    ]
  
  test "DistinctToGenericObject":
    assertSerTokens DistinctToGenericObject(GenericObject[int](id: 123)), [
      Map(none int),
      String("id"),
      I64(123),
      MapEnd()
    ]
  
  test "DistinctGenericObject":
    assertSerTokens DistinctGenericObject[int](GenericObject[int](id: 123)), [
      Map(none int),
      String("id"),
      I64(123),
      MapEnd()
    ]
  
  test "ChildObject":
    assertSerTokens ChildObject(id: 123, text: "123"), [
      Map(none int),
      String("i"),
      I64(123),
      String("text"),
      String("123"),
      MapEnd()
    ]
  
  test "ChildGenericObject":
    assertSerTokens ChildGenericObject[string](id: 123, text: "123"), [
      Map(none int),
      String("i"),
      I64(123),
      String("text"),
      String("123"),
      MapEnd()
    ]
  
  test "ChildRefObject":
    assertSerTokens ChildRefObject(id: 123, text: "123"), [
      Map(none int),
      String("i"),
      I64(123),
      String("text"),
      String("123"),
      MapEnd()
    ]
  
  test "ChildGenericToObject":
    assertSerTokens ChildGenericToObject(id: 123, text: "123"), [
      Map(none int),
      String("i"),
      I64(123),
      String("text"),
      String("123"),
      MapEnd()
    ]
  
  test "ChildOfRefObject":
    assertSerTokens ChildOfRefObject(id: 123, text: "123"), [
      Map(none int),
      String("i"),
      I64(123),
      String("text"),
      String("123"),
      MapEnd()
    ]
  
  test "InfectedChild":
    assertSerTokens InfectedChild(id: 123, firstName: "123"), [
      Map(none int),
      String("i"),
      I64(123),
      String("first_name"),
      String("123"),
      MapEnd()
    ]