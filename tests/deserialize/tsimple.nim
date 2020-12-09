discard """
  output: '''
id int 0
text string 
foo Foo (id: 0)
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

var t = Test()

forDesFields key, value, t:
  echo key, " ", value.type, " ", value
