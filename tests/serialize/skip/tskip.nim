discard """
  output: '''
id
text
  '''
"""

import deser

type
  Test {.ser.} = object
    id: int
    text: string
    useless {.skip.}: string

let t = Test()

forSer(k, v, t):
  echo k
