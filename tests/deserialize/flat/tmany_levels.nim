discard """
  output: '''
id
kek
lol
  '''
"""
import deser

type
  BarTwo {.des.} = object
    lol: int

  BarOne {.des.} = object
    kek: int
    barTwo {.flat.}: BarTwo

  Bar {.des.} = object
    id: int
    barOne {.flat.}: BarOne

  Foo {.des.} = object
    bar {.flat.}: Bar

var t = Foo()

startDes(t):
  forDes(k, v, t):
    echo k
    finish:
      v = some(default(v.get.type))
