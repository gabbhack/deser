discard """
  output: '''
id Option[system.int]
text Option[system.string]
foo Option[tref_des.Foo]
  '''
"""
import
  deser

type
  Foo {.des.} = ref object
    id: int
  Test {.des.} = ref object
    id: int
    text: string
    foo: Foo

let t = new Test

startDes t[]:
  forDes key, value, t[]:
    echo key, " ", value.type
    finish:
      when value.get.type is ref:
        value = some(new(value.get.type))
      else:
        value = some(default(value.get.type))
