discard """
  output: '''
id
text
  '''
"""

import deser

type
  Foo {.ser.} = ref object
    text: string
  Test {.ser.} = ref object
    id: int
    foo {.flat.}: Foo

var t = new(Test)
new(t.foo)

forSer key, value, t[]:
  echo key
