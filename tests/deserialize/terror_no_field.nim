discard """
  output: '''
Missing `text` field
  '''
"""
import
  deser

type
  Foo {.des.} = object
    id: int

  Test {.des.} = object
    id: int
    text: string
    foo: Foo

var t = Test()

try:
  startDes t:
    forDes key, value, t:
      when value.get isnot string:
        finish:
          value = some(default(type(value.get)))
except DeserError:
  echo getCurrentExceptionMsg()
