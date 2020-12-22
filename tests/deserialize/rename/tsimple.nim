discard """
  output: '''
Id
TEXT
  '''
"""

import macros
import deser

# `rename` has a special behavior during deserialization
type
  Foo = object
    id {.rename("Id").}: int
    text {.rename(des = "TEXT").}: string

var f = Foo()

forDesFields key, value, f:
  echo key
