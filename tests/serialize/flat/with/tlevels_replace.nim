discard """
  output: '''
thirdTime int64
fourthTime Time
fourth string
  '''
"""
import macros, times
import deser

proc toString(x: float): string = $x

# `serializeWith` from the Third replaced `serializeWith` from the First
type
  Fourth = object
    fourthTime: Time
    fourth: float
  Third {.serializeWith(toString).} = object
    thirdTime: Time
    fourth {.flat.}: Fourth
  Second = object
    third {.flat.}: Third
  First {.serializeWith(toUnix).} = object
    second {.flat.}: Second

let f = First()

forSerFields key, value, f:
  echo key, " ", value.type
