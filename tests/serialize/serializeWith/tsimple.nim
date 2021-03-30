discard """
  output: '''
123
321
  '''
"""
import times
import deser

type
  Test {.ser.} = object
    time {.serializeWith(toUnix).}: Time
    text: string

let t = Test(time: fromUnix(123), text: "321")

forSer(k, v, t):
  echo v
