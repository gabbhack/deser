import
  deser

type
  TestKind = enum
    True, False

  Foo {.des.} = object
    id: int

  Test {.des.} = object
    id: int
    foo: Foo
    case kind {.untagged.}: TestKind
    of True:
      t: string
    of False:
      f: bool

var t = Test()

startDes t:
  forDes key, value, t:
    when value.get isnot string:
      finish:
        value = some(default(type(value.get)))

assert true
