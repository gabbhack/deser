discard """
  output: '''
Id
text
  '''
"""


import deser

type
  Foo {.ser.} = object
    id {.rename("Id").}: int
    text {.rename(des = "TEXT").}: string

let f = Foo()

forSer key, value, f:
  echo key
