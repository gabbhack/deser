discard """
  output: '''
123
321
  '''
"""
import times
import deser

template tUnix(t: Time): int64 = toUnix(t)

type
  Test {.ser.} = object
    time {.serializeWith(tUnix).}: Time
    text: string

let t = Test(time: fromUnix(123), text: "321")

forSer(k, v, t):
  echo v
