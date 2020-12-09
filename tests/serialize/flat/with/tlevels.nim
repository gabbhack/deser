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
  First {.serializeWith(toUnix).} = object
    second {.flat.}: Second

let f = First()

forSerFields key, value, f:
  echo key, " ", value.type
