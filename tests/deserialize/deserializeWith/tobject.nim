discard """
  output: '''
Option[system.int64]
Option[system.int64]
  '''
"""
import times
import deser

type
  Foo {.des.} = object
    created_at {.deserializeWith(fromUnix).}: Time
    used_at {.deserializeWith(fromUnix).}: Time

var f = Foo()

startDes(f):
  forDes(k, v, f):
    echo v.type
    finish:
      v = some(123.int64)

assert f.created_at.toUnix == 123
assert f.used_at.toUnix == 123
