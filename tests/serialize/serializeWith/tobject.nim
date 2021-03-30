discard """
  output: '''
10
123
321
  '''
"""
import times
import deser

type
  Foo {.ser.} = object
    id: int
    created_at {.serializeWith(toUnix).}: Time
    used_at {.serializeWith(toUnix).}: Time

let f = Foo(id: 10, created_at: fromUnix(123), used_at: fromUnix(321))

forSer(k, v, f):
  echo v
