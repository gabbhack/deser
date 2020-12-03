discard """
  output: '''
123
321
  '''
"""
import macros, times
import deser

proc timeToInt(x: Time): int64 =
  x.toUnix()

type
  Test = object
    time {.serializeWith(timeToInt).}: Time
    text: string

let t = Test(time: fromUnix(123), text: "321")

forSerFields(k, v, t):
  echo v
