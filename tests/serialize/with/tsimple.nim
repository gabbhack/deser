discard """
  output: '''
123
321
  '''
"""
import macros, times
import deser

type
  Test = object
    time {.serializeWith(toUnix).}: Time
    text: string

let t = Test(time: fromUnix(123), text: "321")

forSerFields(k, v, t):
  echo v
