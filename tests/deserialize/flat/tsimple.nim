discard """
  output: '''
id
text
  '''
"""
import macros
import deser

type
  Foo = object
    text: string
  Test = object
    id: int
    foo {.flat.}: Foo

var t = Test()

forDesFields key, value, t:
  echo key
