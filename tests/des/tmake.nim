discard """
  matrix: "; -d:release; --gc:orc; -d:release --gc:orc; --threads:on"
"""
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


proc fromTimestamp(deserializer: var auto): Time =
  fromUnix(deserialize(int64, deserializer))

proc raiseError(objName, fieldValue: auto) =
  raise newException(ValueError, &"Unknown field `{fieldValue}`")


type
  EmptyObject = object

  Object = object
    id*: int

  GenericObject[T] = object
    id: T

  RefObject = ref object
    id: int
  
  ObjectWithRef = object
    id: ref int
  
  InheritObject {.renameAll: SnakeCase.} = object of RootObj
    id* {.renamed: "i".}: int
  
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

  SkipAllPrivateObject {.skipPrivate.} = object
    public*: int
    private: int
  
  SkipDesPrivateObject {.skipPrivateDeserializing.} = object
    public*: int
    private: int

  MultiCaseObject = object
    case kind: bool
    of true:
      yes: string
    else:
      no: string

    case kind2: bool
    of true:
      yes2: string
    else:
      no2: string

  MultiCaseObjectUntagged = object
    case kind {.untagged.}: bool
    of true:
      yes: string
    of false:
      no: string

    case kind2: bool
    of true:
      yes2: string
    else:
      no2: string

  MultiCaseObjectAllUntagged = object
    case kind {.untagged.}: bool
    of true:
      yes: string
    of false:
      no: string

    case kind2 {.untagged.}: bool
    of true:
      yes2: string
    of false:
      no2: string
  
  RenameWithCase = object
    lolKek {.renameDeserialize(SnakeCase).}: string
    kekLol {.renamed(SnakeCase).}: string


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

proc `==`*(x, y: MultiCaseObject | MultiCaseObjectUntagged | MultiCaseObjectAllUntagged): bool =
  if x.kind == y.kind and x.kind2 == y.kind2:
    case x.kind
    of true:
      if x.kind2:
        return x.yes == y.yes and x.yes2 == y.yes2
      else:
        return x.yes == y.yes and x.no2 == y.no2
    of false:
      if x.kind2:
        return x.no == y.no and x.yes2 == y.yes2
      else:
        return x.no == y.no and x.no2 == y.no2
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
  RenameAllObject,
  ChildObject,
  ChildGenericObject,
  ChildGenericToObject,
  ChildRefObject,
  ChildOfRefObject,
  InfectedChild,
  SkipAllPrivateObject,
  SkipDesPrivateObject,
  MultiCaseObject,
  MultiCaseObjectUntagged,
  MultiCaseObjectAllUntagged,
  RenameWithCase
], public=true)


suite "makeDeserializable":
  test "Deserialize at CT":
    static:
      assertDesTokens EmptyObject(), [
        initStructToken("EmptyObject", 0),
        initStructEndToken()
      ]

  test "EmptyObject":
    assertDesTokens EmptyObject(), [
      initStructToken("EmptyObject", 0),
      initStructEndToken()
    ]

  test "Object":
    assertDesTokens Object(id: 123), [
      initStructToken("Object", 1),
      initStringToken("id"),
      initI64Token(123),
      initStructEndToken()
    ]
  
  test "GenericObject":
    assertDesTokens GenericObject[int](id: 123), [
      initStructToken("GenericObject", 1),
      initStringToken("id"),
      initI64Token(123),
      initStructEndToken()
    ]
  
  test "RefObject":
    assertDesTokens RefObject(id: 123), [
      initStructToken("RefObject", 1),
      initStringToken("id"),
      initI64Token(123),
      initStructEndToken()
    ]
  
  test "ObjectWithRef":
    let temp = new int
    temp[] = 123
    assertDesTokens ObjectWithRef(id: temp), [
      initStructToken("ObjectWithRef", 1),
      initStringToken("id"),
      initI64Token(123),
      initStructEndToken()
    ]
  
  test "InheritObject":
    assertDesTokens InheritObject(id: 123), [
      initStructToken("InheritObject", 1),
      initStringToken("i"),
      initI64Token(123),
      initStructEndToken()
    ]
  
  test "CaseObject":
    assertDesTokens CaseObject(kind: true), [
      initMapToken(none int),
      initStringToken("kind"),
      initBoolToken(true),
      initStringToken("yes"),
      initStringToken(""),
      initMapEndToken()
    ]

    assertDesTokens CaseObject(kind: false), [
      initMapToken(none int),
      initStringToken("kind"),
      initBoolToken(false),
      initMapEndToken()
    ]


  test "UntaggedCaseObject":
    assertDesTokens UntaggedCaseObject(kind: true), [
      initMapToken(none int),
      initStringToken("yes"),
      initStringToken(""),
      initMapEndToken()
    ]

    assertDesTokens UntaggedCaseObject(kind: false), [
      initMapToken(none int),
      initMapEndToken()
    ]

  test "SkipObject":
    assertDesTokens SkipObject(), [
      initStructToken("SkipObject", 0),
      initStructEndToken()
    ]
  
  test "DeserializeWithObject":
    assertDesTokens DeserializeWithObject(date: fromUnix(123)), [
      initStructToken("DeserializeWithObject", 1),
      initStringToken("date"),
      initI64Token(123),
      initStructEndToken()
    ]
  
  test "RenameObject":
    assertDesTokens RenameObject(name: "123", kek: "123"), [
      initStructToken("RenameObject", 1),
      initStringToken("fullname"),
      initStringToken("123"),
      initStringToken("lol"),
      initStringToken("123"),
      initStructEndToken()
    ]
  
  test "DefaultObject":
    assertDesTokens DefaultObject(id: 123, integer: 0), [
      initStructToken("DefaultObject", 1),
      initStructEndToken()
    ]

  # crash on "-d:release --gc:refc"
  #[
    test "OnUnknownObject":
      expect(ValueError):
        assertDesTokens OnUnknownObject(), [
          initStructToken("OnUnknownObject", 1),
          initStringToken("test"),
          initStringToken("123"),
          initStructEndToken()
        ]
  ]#

  test "Ignore extra fields":
    assertDesTokens Object(id: 123), [
      initStructToken("Object", 1),
      initStringToken("id"),
      initI64Token(123),
      initStringToken("text"),
      initStringToken("text"),
      initStructEndToken()
    ]
  
  test "RenameAllObject":
    assertDesTokens RenameAllObject(kind: true), [
      initStructToken("RenameAllObject", 2),
      initStringToken("text"),
      initStringToken(""),
      initStringToken("firstName"),
      initStringToken(""),
      initStringToken("kind"),
      initBoolToken(true),
      initStringToken("last_name"),
      initStringToken(""),
      initStructEndToken()
    ]

  test "ChildObject":
    assertDesTokens ChildObject(id: 123, text: "123"), [
      initStructToken("ChildObject", 2),
      initStringToken("i"),
      initI64Token(123),
      initStringToken("text"),
      initStringToken("123"),
      initStructEndToken()
    ]
  
  test "ChildGenericObject":
    assertDesTokens ChildGenericObject[string](id: 123, text: "123"), [
      initStructToken("ChildGenericObject", 2),
      initStringToken("i"),
      initI64Token(123),
      initStringToken("text"),
      initStringToken("123"),
      initStructEndToken()
    ]
  
  test "ChildRefObject":
    assertDesTokens ChildRefObject(id: 123, text: "123"), [
      initStructToken("ChildRefObject", 2),
      initStringToken("i"),
      initI64Token(123),
      initStringToken("text"),
      initStringToken("123"),
      initStructEndToken()
    ]
  
  test "ChildGenericToObject":
    assertDesTokens ChildGenericToObject(id: 123, text: "123"), [
      initStructToken("ChildGenericToObject", 2),
      initStringToken("i"),
      initI64Token(123),
      initStringToken("text"),
      initStringToken("123"),
      initStructEndToken()
    ]
  
  test "ChildOfRefObject":
    assertDesTokens ChildOfRefObject(id: 123, text: "123"), [
      initStructToken("ChildOfRefObject", 2),
      initStringToken("i"),
      initI64Token(123),
      initStringToken("text"),
      initStringToken("123"),
      initStructEndToken()
    ]
  
  test "InfectedChild":
    assertDesTokens InfectedChild(id: 123, firstName: "123"), [
      initStructToken("InfectedChild", 2),
      initStringToken("i"),
      initI64Token(123),
      initStringToken("first_name"),
      initStringToken("123"),
      initStructEndToken()
    ]
  
  test "SkipAllPrivateObject":
    assertDesTokens SkipAllPrivateObject(public: 123), [
      initStructToken("SkipAllPrivateObject", 1),
      initStringToken("public"),
      initI64Token(123),
      initStructEndToken()
    ]
  
  test "SkipDesPrivateObject":
    assertDesTokens SkipDesPrivateObject(public: 123), [
      initStructToken("SkipAllPrivateObject", 1),
      initStringToken("public"),
      initI64Token(123),
      initStructEndToken()
    ]

  test "MultiCaseObject":
    assertDesTokens MultiCaseObject(kind: true, yes: "yes", kind2: false, no2: "no"), [
      initMapToken(none int),
      initStringToken("kind"),
      initBoolToken(true),
      initStringToken("yes"),
      initStringToken("yes"),
      initStringToken("kind2"),
      initBoolToken(false),
      initStringToken("no2"),
      initStringToken("no"),
      initMapEndToken()
    ]
  
  test "MultiCaseObjectUntagged":
    assertDesTokens MultiCaseObjectUntagged(kind: true, yes: "yes", kind2: false, no2: "no"), [
      initMapToken(none int),
      initStringToken("yes"),
      initStringToken("yes"),
      initStringToken("kind2"),
      initBoolToken(false),
      initStringToken("no2"),
      initStringToken("no"),
      initMapEndToken()
    ]
  
  test "MultiCaseObjectAllUntagged":
    assertDesTokens MultiCaseObjectAllUntagged(kind: true, yes: "yes", kind2: false, no2: "no"), [
      initMapToken(none int),
      initStringToken("yes"),
      initStringToken("yes"),
      initStringToken("no2"),
      initStringToken("no"),
      initMapEndToken()
    ]
  
  test "RenameWithCase":
    assertDesTokens RenameWithCase(), [
      initMapToken(none int),
      initStringToken("lol_kek"),
      initStringToken(""),
      initStringToken("kek_lol"),
      initStringToken(""),
      initMapEndToken()
    ]
