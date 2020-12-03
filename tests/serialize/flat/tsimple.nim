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

let t = Test()

forSerFields key, value, t:
  echo key
