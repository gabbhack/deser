import deser

type
  Foo {.des.} = object
    case kind: bool
    of true, false:
      foo: int

var t: Foo

startDes(t):
  forDes(k, v, t):
    when k == "kind":
      finish:
        v = some(true)
    else:
      finish:
        v = some(123)

assert t.foo == 123
