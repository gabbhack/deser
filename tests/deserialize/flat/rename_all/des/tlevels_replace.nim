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
  Third {.renameAll(des=rkUpperKebabCase).} = object
    thirdTime: int64
    fourth {.flat.}: Fourth
  Second = object
    third {.flat.}: Third
  First {.renameAll(des=rkSnakeCase).} = object
    firstElement: int64
    second {.flat.}: Second

var f = First()

forDesFields key, value, f:
  echo key
