discard """
  output: '''
id
text
  '''
"""
import macros
import deser

type
  Foo = ref object
    text: string
  Test = ref object
    id: int
    foo {.flat.}: Foo

var t = new(Test)
new(t.foo)

forDesFields key, value, t:
  echo key
