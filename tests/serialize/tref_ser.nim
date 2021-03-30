discard """
  output: '''
id int
text string
foo Foo
  '''
"""

import deser

type
  Foo {.ser.} = ref object
    id: int
  Test {.ser.} = ref object
    id: int
    text: string
    foo: Foo

let t = new(Test)

forSer key, value, t[]:
  echo key, " ", value.type
