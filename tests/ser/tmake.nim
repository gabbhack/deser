import std/[unittest]

import deser
import deser/test

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

proc serialize[Serializer](self: ref int, serializer: var Serializer) =
  serializer.serializeInt(self[])

makeSerializable(Object)
makeSerializable(GenericObject)
makeSerializable(ObjectWithRef)
makeSerializable(RefObject)
makeSerializable(InheritObject)
makeSerializable(CaseObject)
makeSerializable(UntaggedCaseObject)

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
  
  test "case object":
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
  
  test "untagged case object":
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
