discard """
  output: '''
10
123
321
  '''
"""
import macros, times
import deser

type
  Foo {.serializeWith(toUnix).} = object
    id: int
    created_at: Time
    used_at: Time

let f = Foo(id: 10, created_at: fromUnix(123), used_at: fromUnix(321))

forSerFields(k, v, f):
  echo v
