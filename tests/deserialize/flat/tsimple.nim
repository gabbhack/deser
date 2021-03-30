discard """
  output: '''
id
text
  '''
"""
import deser

type
  Foo {.des.} = object
    text: string
  Test {.des.} = object
    id: int
    foo {.flat.}: Foo

var t = Test()

startDes(t):
  forDes(k, v, t):
    echo k
    finish:
      v = some(default(v.get.type))
