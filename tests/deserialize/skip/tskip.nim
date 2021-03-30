discard """
  output: '''
id
text
  '''
"""

import deser

type
  Test {.des.} = object
    id: int
    text: string
    useless {.skip.}: string

var t = Test()

startDes(t):
  forDes(k, v, t):
    echo k
    finish:
      v = some(default(v.get.type))
