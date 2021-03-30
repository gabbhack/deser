
import deser

proc skipFloat(x: float): bool = true

type
  Test {.ser.} = object
    id: int
    uselessInt {.skipSerializeIf(skipFloat).}: int

let t = Test()

# TODO check error text
assert not compiles(forSer(k, v, t))
