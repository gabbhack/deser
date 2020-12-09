discard """
  output: '''
thirdTime int64
fourthTime int64
  '''
"""
import macros, times
import deser

type
  Fourth = object
    fourthTime: Time
  Third = object
    thirdTime: Time
    fourth {.flat.}: Fourth
  Second = object
    third {.flat.}: Third
  First {.deserializeWith(fromUnix).} = object
    second {.flat.}: Second

var f = First()

forDesFields key, value, f:
  echo key, " ", value.type
