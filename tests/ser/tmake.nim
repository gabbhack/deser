discard """
  matrix: "; -d:release; --gc:orc; -d:release --gc:orc"
"""
{.experimental: "views".}
import std/[unittest, options, times]

import deser
import deser/utils
import deser/test

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

  User = object
    id: int

  Pagination = object
    limit: int64
    offset: int64
    total: int64


proc serialize[Serializer](self: ref int, serializer: var Serializer) =
  serializer.serializeInt(self[])

makeSerializable(Object)
makeSerializable(GenericObject)
makeSerializable(ObjectWithRef)
makeSerializable(RefObject)
makeSerializable(InheritObject)
makeSerializable(CaseObject)
makeSerializable(UntaggedCaseObject)
makeSerializable(SkipIfObject)
makeSerializable(SerializeWithObject)
makeSerializable(RenameObject)

makeSerializable(User)
makeSerializable(Pagination)

suite "makeSerializable":
  test "simple":
    serTokens Object(id: 123), [
      Struct("Object"),
      String("id"),
      Integer(123),
      StructEnd()
    ]
  
  test "generic":
    serTokens GenericObject[int](id: 123), [
      Struct("GenericObject"),
      String("id"),
      Integer(123),
      StructEnd()
    ]
  
  test "with ref":
    let refInt = new int
    refInt[] = 123
    serTokens ObjectWithRef(id: refInt), [
      Struct("ObjectWithRef"),
      String("id"),
      Integer(123),
      StructEnd()
    ]
  
  test "ref":
    serTokens RefObject(id: 123), [
      Struct("RefObject"),
      String("id"),
      Integer(123),
      StructEnd()
    ]
  
  test "inherit":
    serTokens InheritObject(id: 123), [
      Struct("InheritObject"),
      String("id"),
      Integer(123),
      StructEnd()
    ]
  
  test "case":
    serTokens CaseObject(kind: true, yes: "yes"), [
      Struct("CaseObject"),
      String("kind"),
      Boolean(true),
      String("yes"),
      String("yes"),
      StructEnd()
    ]

    serTokens CaseObject(kind: false), [
      Struct("CaseObject"),
      String("kind"),
      Boolean(false),
      StructEnd()
    ]
  
  test "untagged case":
    serTokens UntaggedCaseObject(kind: true, yes: "yes"), [
      Struct("UntaggedCaseObject"),
      String("yes"),
      String("yes"),
      StructEnd()
    ]

    serTokens UntaggedCaseObject(kind: false), [
      Struct("UntaggedCaseObject"),
      StructEnd()
    ]
  
  test "skipSerializeIf":
    serTokens SkipIfObject(text: some "text"), [
      Struct("SkipIfObject"),
      String("text"),
      Some(),
      StructEnd()
    ]

    serTokens SkipIfObject(text: none string), [
      Struct("SkipIfObject"),
      StructEnd()
    ]
  
  test "serializeWith":
    let date = now()
    serTokens SerializeWithObject(date: date), [
      Struct("SerializeWithObject"),
      String("date"),
      Integer(int(date.toTime.toUnix)),
      StructEnd()
    ]
  
  test "renameSerialize":
    serTokens RenameObject(name: "Name"), [
      Struct("RenameObject"),
      String("fullname"),
      String("Name"),
      StructEnd()
    ]