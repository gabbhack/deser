import deser

type
  Foo {.des.} = object
    id {.des, rename().}: int

var t = Foo()

startDes(t):
  forDes(k, v, t):
    assert k == "id"
    finish:
      v = some(default(v.get.type))
