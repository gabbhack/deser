discard """
  matrix: "; -d:release; --gc:orc; -d:release --gc:orc; --threads:on"
"""
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


proc toTimestamp[Serializer](date: DateTime, serializer: var Serializer) =
  date.toTime.toUnix.serialize(serializer)


type
  Object = object
    id*: int

  GenericObject[T] = object
    id: T
  
  ObjectWithRef = object
    id: ref int
  
  RefObject = ref object
    id: int

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
  
  SkipSerPrivateObject {.skipPrivateSerializing.} = object
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
    lolKek {.renameSerialize(SnakeCase).}: string
    kekLol {.renamed(SnakeCase).}: string

  CaseObjectMultiBranchKind = enum
    First, Second, Third, Fourth

  CaseObjectMultiBranch = object
    case kind: CaseObjectMultiBranchKind
    of First, Second:
      first: string
    of Third, Fourth:
      second: string


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
  ChildObject,
  ChildGenericObject,
  ChildGenericToObject,
  ChildRefObject,
  ChildOfRefObject,
  InfectedChild,
  SkipAllPrivateObject,
  SkipSerPrivateObject,
  MultiCaseObject,
  MultiCaseObjectUntagged,
  MultiCaseObjectAllUntagged,
  RenameWithCase,
  CaseObjectMultiBranch
], public=true)


suite "makeSerializable":
  test "Serialize at CT":
    static:
      assertSerTokens Object(id: 123), [
        initMapToken(none int),
        initStringToken("id"),
        initI64Token(123),
        initMapEndToken()
        ]

  test "simple":
    assertSerTokens Object(id: 123), [
      initMapToken(none int),
      initStringToken("id"),
      initI64Token(123),
      initMapEndToken()
    ]
  
  test "generic":
    assertSerTokens GenericObject[int](id: 123), [
      initMapToken(none int),
      initStringToken("id"),
      initI64Token(123),
      initMapEndToken()
    ]
  
  test "with ref":
    let refInt = new int
    refInt[] = 123
    assertSerTokens ObjectWithRef(id: refInt), [
      initMapToken(none int),
      initStringToken("id"),
      initI64Token(123),
      initMapEndToken()
    ]
  
  test "ref":
    assertSerTokens RefObject(id: 123), [
      initMapToken(none int),
      initStringToken("id"),
      initI64Token(123),
      initMapEndToken()
    ]
  
  test "inherit":
    assertSerTokens InheritObject(id: 123), [
      initMapToken(none int),
      initStringToken("i"),
      initI64Token(123),
      initMapEndToken()
    ]
  
  test "case":
    assertSerTokens CaseObject(kind: true, yes: "yes"), [
      initMapToken(none int),
      initStringToken("kind"),
      initBoolToken(true),
      initStringToken("yes"),
      initStringToken("yes"),
      initMapEndToken()
    ]

    assertSerTokens CaseObject(kind: false), [
      initMapToken(none int),
      initStringToken("kind"),
      initBoolToken(false),
      initMapEndToken()
    ]
  
  test "untagged case":
    assertSerTokens UntaggedCaseObject(kind: true, yes: "yes"), [
      initMapToken(none int),
      initStringToken("yes"),
      initStringToken("yes"),
      initMapEndToken()
    ]

    assertSerTokens UntaggedCaseObject(kind: false), [
      initMapToken(none int),
      initMapEndToken()
    ]
  
  test "skipSerializeIf":
    assertSerTokens SkipIfObject(text: some "text"), [
      initMapToken(none int),
      initStringToken("text"),
      initSomeToken(),
      initMapEndToken()
    ]

    assertSerTokens SkipIfObject(text: none string), [
      initMapToken(none int),
      initMapEndToken()
    ]
  
  test "serializeWith":
    let date = now()
    assertSerTokens SerializeWithObject(date: date), [
      initMapToken(none int),
      initStringToken("date"),
      initI64Token(int(date.toTime.toUnix)),
      initMapEndToken()
    ]
  
  test "renameSerialize":
    assertSerTokens RenameObject(name: "Name"), [
      initMapToken(none int),
      initStringToken("fullname"),
      initStringToken("Name"),
      initMapEndToken()
    ]
  
  test "RenameAllObject":
    assertSerTokens RenameAllObject(kind: true), [
      initMapToken(none int),
      initStringToken("text"),
      initStringToken(""),
      initStringToken("firstName"),
      initStringToken(""),
      initStringToken("kind"),
      initBoolToken(true),
      initStringToken("last_name"),
      initStringToken(""),
      initMapEndToken()
    ]
  
  test "ChildObject":
    assertSerTokens ChildObject(id: 123, text: "123"), [
      initMapToken(none int),
      initStringToken("i"),
      initI64Token(123),
      initStringToken("text"),
      initStringToken("123"),
      initMapEndToken()
    ]
  
  test "ChildGenericObject":
    assertSerTokens ChildGenericObject[string](id: 123, text: "123"), [
      initMapToken(none int),
      initStringToken("i"),
      initI64Token(123),
      initStringToken("text"),
      initStringToken("123"),
      initMapEndToken()
    ]
  
  test "ChildRefObject":
    assertSerTokens ChildRefObject(id: 123, text: "123"), [
      initMapToken(none int),
      initStringToken("i"),
      initI64Token(123),
      initStringToken("text"),
      initStringToken("123"),
      initMapEndToken()
    ]
  
  test "ChildGenericToObject":
    assertSerTokens ChildGenericToObject(id: 123, text: "123"), [
      initMapToken(none int),
      initStringToken("i"),
      initI64Token(123),
      initStringToken("text"),
      initStringToken("123"),
      initMapEndToken()
    ]
  
  test "ChildOfRefObject":
    assertSerTokens ChildOfRefObject(id: 123, text: "123"), [
      initMapToken(none int),
      initStringToken("i"),
      initI64Token(123),
      initStringToken("text"),
      initStringToken("123"),
      initMapEndToken()
    ]
  
  test "InfectedChild":
    assertSerTokens InfectedChild(id: 123, firstName: "123"), [
      initMapToken(none int),
      initStringToken("i"),
      initI64Token(123),
      initStringToken("first_name"),
      initStringToken("123"),
      initMapEndToken()
    ]
  
  test "SkipAllPrivateObject":
    assertSerTokens SkipAllPrivateObject(public: 123), [
      initMapToken(none int),
      initStringToken("public"),
      initI64Token(123),
      initMapEndToken()
    ]
  
  test "SkipDesPrivateObject":
    assertSerTokens SkipSerPrivateObject(public: 123), [
      initMapToken(none int),
      initStringToken("public"),
      initI64Token(123),
      initMapEndToken()
    ]
  
  test "MultiCaseObject":
    assertSerTokens MultiCaseObject(kind: true, yes: "yes", kind2: false, no2: "no"), [
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
    assertSerTokens MultiCaseObjectUntagged(kind: true, yes: "yes", kind2: false, no2: "no"), [
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
    assertSerTokens MultiCaseObjectAllUntagged(kind: true, yes: "yes", kind2: false, no2: "no"), [
      initMapToken(none int),
      initStringToken("yes"),
      initStringToken("yes"),
      initStringToken("no2"),
      initStringToken("no"),
      initMapEndToken()
    ]

  test "RenameWithCase":
    assertSerTokens RenameWithCase(), [
      initMapToken(none int),
      initStringToken("lol_kek"),
      initStringToken(""),
      initStringToken("kek_lol"),
      initStringToken(""),
      initMapEndToken()
    ]

  test "CaseObjectMultiBranch":
    assertSerTokens CaseObjectMultiBranch(kind: First, first: "123"), [
      initMapToken(none int),
      initStringToken("kind"),
      initEnumToken(),
      initStringToken("first"),
      initStringToken("123"),
      initMapEndToken()
    ]

    assertSerTokens CaseObjectMultiBranch(kind: Third, second: "123"), [
      initMapToken(none int),
      initStringToken("kind"),
      initEnumToken(),
      initStringToken("second"),
      initStringToken("123"),
      initMapEndToken()
    ]

  test "Serialize nil ref as none":
    # ref without generated `serialize`
    var temp: ref int
    assertSerTokens temp, [
      initNoneToken()
    ]

    # ref with generated `serialize`
    var temp2: ChildRefObject
    assertSerTokens temp2, [
      initNoneToken()
    ]
