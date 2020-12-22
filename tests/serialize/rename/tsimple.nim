discard """
  output: '''
Id
text
  '''
"""

import macros
import deser

type
  Foo = object
    id {.rename("Id").}: int
    text {.rename(des = "TEXT").}: string

let f = Foo()

forSerFields key, value, f:
  echo key
