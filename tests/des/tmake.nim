discard """
  matrix: "; -d:release; --gc:orc; -d:release --gc:orc"
"""
{.experimental: "views".}
import std/[unittest, times, options]

import deser
import deser/test


proc fromTimestamp(deserializer: var auto): Time = fromUnix(deserialize(int64, deserializer))


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


proc `==`*(x, y: ObjectWithRef): bool = x.id[] == y.id[]

proc `==`*(x, y: CaseObject | UntaggedCaseObject): bool =
  if x.kind == y.kind:
    if x.kind == true and y.kind == true:
      return x.yes == y.yes
    return true
  return false

proc `$`*(x: ref): string = $x[]


makeDeserializable(EmptyObject)
makeDeserializable(Object)
makeDeserializable(GenericObject)
makeDeserializable(RefObject)
makeDeserializable(ObjectWithRef)
makeDeserializable(InheritObject)
makeDeserializable(CaseObject)
makeDeserializable(UntaggedCaseObject)
makeDeserializable(SkipObject)
makeDeserializable(DeserializeWithObject)
makeDeserializable(RenameObject)


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
    assertDesTokens RenameObject(name: "123"), [
      Struct("RenameObject", 1),
      String("fullname"),
      String("123"),
      StructEnd()
    ]
  
  test "Ignore extra fields":
    assertDesTokens Object(id: 123), [
      Struct("Object", 1),
      String("id"),
      I64(123),
      String("text"),
      String("text"),
      StructEnd()
    ]
