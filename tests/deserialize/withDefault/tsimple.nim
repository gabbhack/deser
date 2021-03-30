import deser

template defaultText: string = "213"

type
  Foo {.des.} = object
    id {.withDefault(12).}: int64
    text {.withDefault(defaultText()).}: string

var t: Foo

startDes(t):
  forDes(k, v, t):
    discard

assert t.id == 12
assert t.text == "213"
