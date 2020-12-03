import macros
import deser

proc skipFloat(x: float): bool = true

type
  Test = object
    id: int
    uselessInt {.skipSerializeIf(skipFloat).}: int

let t = Test()

assert not compiles(forSerFields(k, v, t))
