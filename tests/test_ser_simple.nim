discard """
  output: '''
id int 123
text string 321
foo Foo (id: 345)
  '''
"""
import macros
import deser

type
  Foo = object
    id: int
  Test = object
    id: int
    text: string
    foo: Foo

let t = Test(id: 123, text: "321", foo: Foo(id: 345))

forSerFields key, value, t:
  echo key, " ", value.type, " ", value
