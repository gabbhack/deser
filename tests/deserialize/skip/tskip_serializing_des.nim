discard """
  output: '''
id
text
usefull
  '''
"""

import deser

type
  Test {.des.} = object
    id: int
    text: string
    usefull {.skipSerializing.}: string

var t = Test()

startDes(t):
  forDes(k, v, t):
    echo k
    finish:
      v = some(default(v.get.type))
