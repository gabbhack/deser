import macros
import deser

type
  Foo = object
    id {.rename("Id").}: int

let f = Foo()

forSerFields key, value, f:
  assert key == "Id"
