discard """
  output: '''
id
text
  '''
"""

import deser

type
  Foo {.ser.} = object
    text: string
  Test {.ser.} = object
    id: int
    foo {.flat.}: Foo

let t = Test()

forSer key, value, t:
  echo key
