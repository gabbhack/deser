discard """
  output: '''
int64
int64
  '''
"""
import macros, times
import deser

type
  Foo {.deserializeWith(fromUnix).} = object
    created_at: Time
    used_at: Time

var f = Foo()

forDesFields(k, v, f):
  echo v.type
  v = 123

assert f.created_at.toUnix == 123
assert f.used_at .toUnix == 123
