discard """
  output: '''
third_time
fourth_time
  '''
"""
import macros
import deser

type
  Fourth = object
    fourthTime: int64
  Third = object
    thirdTime: int64
    fourth {.flat.}: Fourth
  Second = object
    third {.flat.}: Third
  First {.renameAll(des=rkSnakeCase).} = object
    second {.flat.}: Second

var f = First()

forDesFields key, value, f:
  echo key
