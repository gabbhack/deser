discard """
  output: '''
id
kind
first
second
third
  '''
"""
import deser

type
  FooKind = enum
    First,
    Second,
    Third

  Foo {.des.} = object
    id: int
    case kind: FooKind
    of First:
      first: string
    of Second:
      second: string
    of Third:
      third: string

var t: Foo

startDes(t):
  forDes(k, v, t):
    echo k
    finish:
      v = some(default(v.get.type))
