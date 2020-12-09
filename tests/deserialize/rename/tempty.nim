import macros
import deser

type
  Foo = object
    id {.rename().}: int

var f = Foo()

forDesFields key, value, f:
  assert key == "id"
