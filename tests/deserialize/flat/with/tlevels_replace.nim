discard """
  output: '''
thirdTime int64
fourthTime Time
fourth float
  '''
"""
import macros, times
import deser

proc fromFloat(x: float): string = $x

# `deserializeWith` from the Third replaced `deserializeWith` from the First
type
  Fourth = object
    fourthTime: Time
    fourth: string
  Third {.deserializeWith(fromFloat).} = object
    thirdTime: Time
    fourth {.flat.}: Fourth
  Second = object
    third {.flat.}: Third
  First {.deserializeWith(fromUnix).} = object
    second {.flat.}: Second

var f = First()

forDesFields key, value, f:
  echo key, " ", value.type
