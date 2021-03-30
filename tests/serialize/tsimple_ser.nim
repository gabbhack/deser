discard """
  output: '''
id int 123
text string 321
foo Foo (id: 345)
  '''
"""

import deser

type
  Foo {.ser.} = object
    id: int
  Test {.ser.} = object
    id: int
    text: string
    foo: Foo

let t = Test(id: 123, text: "321", foo: Foo(id: 345))

forSer key, value, t:
  echo key, " ", value.type, " ", value
