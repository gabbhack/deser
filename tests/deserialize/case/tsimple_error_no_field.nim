discard """
  output: '''
Missing `t` field
  '''
"""
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
    case kind: TestKind
    of True:
      t: string
    else:
      f: bool

var t = Test()

try:
  startDes t:
    forDes key, value, t:
      when value.get isnot string:
        finish:
          value = some(default(type(value.get)))
except DeserError:
  echo getCurrentExceptionMsg()
