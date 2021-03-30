import times
import deser

type
  Test {.ser.} = object
    time {.serializeWith(toUnix).}: int
    text: string

let t = Test(time: 123, text: "321")

# TODO check error text
assert not compiles(forSer(k, v, t))
