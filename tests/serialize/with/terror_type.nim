import macros, times
import deser

proc timeToInt(x: Time): int64 =
  x.toUnix()

type
  Test = object
    time {.serializeWith(timeToInt).}: int
    text: string

let t = Test(time: 123, text: "321")

assert not compiles(forSerFields(k, v, t))
