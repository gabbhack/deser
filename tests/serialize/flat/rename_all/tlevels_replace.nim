discard """
  output: '''
first_element
THIRD-TIME
FOURTH-TIME
  '''
"""
import macros
import deser

# `renameAll` from the Third replaced `renameAll` from the First
type
  Fourth = object
    fourthTime: int64
  Third {.renameAll(rkUpperKebabCase).} = object
    thirdTime: int64
    fourth {.flat.}: Fourth
  Second = object
    third {.flat.}: Third
  First {.renameAll(rkSnakeCase).} = object
    firstElement: int64
    second {.flat.}: Second

let f = First()

forSerFields key, value, f:
  echo key
