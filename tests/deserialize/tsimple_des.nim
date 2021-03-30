discard """
  output: '''
id Option[system.int] None[int]
text Option[system.string] None[string]
foo Option[tsimple_des.Foo] None[Foo]
  '''
"""
import
  deser

type
  Foo {.des.} = object
    id: int
  Test {.des.} = object
    id: int
    text: string
    foo: Foo

var t = Test()

startDes t:
  forDes key, value, t:
    echo key, " ", value.type, " ", value
    finish:
      value = some(default(value.get.type))
