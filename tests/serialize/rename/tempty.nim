import macros
import deser

type
  Foo = object
    id {.rename().}: int

let f = Foo()

forSerFields key, value, f:
  assert key == "id"
