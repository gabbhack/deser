import macros, times
import deser

type
  Test = object
    text {.deserializeWith(fromUnix).}: string

var t = Test()

assert not compiles(forDesFields(k, v, t))
