import times
import deser

type
  Test = object
    text {.deserializeWith(fromUnix).}: string

var t = Test()

# TODO check error text
assert not compiles(forDesFields(k, v, t))
