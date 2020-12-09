discard """
  output: '''
int64
string
  '''
"""
import macros, times
import deser

type
  Test = object
    time {.deserializeWith(fromUnix).}: Time
    text: string

var t = Test()

forDesFields(k, v, t):
  echo v.type
  when v is int64:
    v = 123

assert t.time.toUnix == 123
