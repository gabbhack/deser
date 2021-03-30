
import deser

type
  Foo {.ser.} = object
    id {.rename().}: int

let f = Foo()

forSer key, value, f:
  assert key == "id"
