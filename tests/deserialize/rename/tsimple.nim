discard """
  output: '''
Id
TEXT
  '''
"""


import deser

# `rename` has a special behavior during deserialization
type
  Foo {.des.} = object
    id {.rename("Id").}: int
    text {.rename(des = "TEXT").}: string

var t = Foo()

startDes(t):
  forDes(k, v, t):
    echo k
    finish:
      v = some(default(v.get.type))
