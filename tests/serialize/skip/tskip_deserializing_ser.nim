discard """
  output: '''
id
text
usefull
  '''
"""

import deser

type
  Test {.ser.} = object
    id: int
    text: string
    usefull {.skipDeserializing.}: string

let t = Test()

forSer(k, v, t):
  echo k
