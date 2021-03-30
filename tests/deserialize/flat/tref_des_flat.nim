discard """
  output: '''
id
text
  '''
"""
import deser

type
  Foo {.des.} = ref object
    text: string
  Test {.des.} = ref object
    id: int
    foo {.flat.}: Foo

var t = new(Test)
new(t.foo)

startDes(t[]):
  forDes(k, v, t[]):
    echo k
    finish:
      v = some(default(v.get.type))
