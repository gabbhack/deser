import macros, times
import deser

type
  Test = object
    time {.serializeWith(toUnix).}: int
    text: string

let t = Test(time: 123, text: "321")

assert not compiles(forSerFields(k, v, t))
