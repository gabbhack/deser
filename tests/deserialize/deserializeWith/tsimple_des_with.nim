discard """
  output: '''
Option[system.int64]
Option[system.string]
  '''
"""
import times
import deser

type
  Test {.des.} = object
    time {.deserializeWith(fromUnix).}: Time
    text: string

var t = Test()

startDes(t):
  forDes(k, v, t):
    echo v.type
    when v.get.type is int64:
      finish:
        v = some(123.int64)
    else:
      finish:
        v = some("123")

assert t.time.toUnix == 123
assert t.text == "123"
