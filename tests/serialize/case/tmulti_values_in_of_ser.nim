import deser

type
  Foo {.ser.} = object
    case kind: bool
    of true, false:
      foo: int

var t = Foo(kind: true, foo: 123)

forSer(k, v, t):
  when k == "kind":
    assert v == true
  else:
    assert v == 123
