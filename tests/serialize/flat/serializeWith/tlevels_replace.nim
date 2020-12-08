discard """
  output: '''
thirdTime Time
fourthTime int64
fourth string
  '''
"""
import macros, times
import deser

proc fromFloat(x: float): string = $x

# `serializeWith` from the Third replaced `serializeWith` from the First
type
  Fourth = object
    fourthTime: int64
    fourth: float
  Third {.serializeWith(fromFloat).} = object
    thirdTime: int64
    fourth {.flat.}: Fourth
  Second = object
    third {.flat.}: Third
  First {.serializeWith(fromUnix).} = object
    second {.flat.}: Second

let f = First()

forSerFields key, value, f:
  echo key, " ", value.type
