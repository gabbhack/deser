discard """
  output: '''
id int
text string
foo Foo
  '''
"""
import macros
import deser

type
  Foo = ref object
    id: int
  Test = ref object
    id: int
    text: string
    foo: Foo

let t = new Test

forDesFields key, value, t:
  echo key, " ", value.type
