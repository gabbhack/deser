discard """
  output: '''
thirdTime Time
fourthTime Time
  '''
"""
import macros, times
import deser

type
  Fourth = object
    fourthTime: int64
  Third = object
    thirdTime: int64
    fourth {.flat.}: Fourth
  Second = object
    third {.flat.}: Third
  First {.serializeWith(fromUnix).} = object
    second {.flat.}: Second

let f = First()

forSerFields key, value, f:
  echo key, " ", value.type
