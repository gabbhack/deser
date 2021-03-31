discard """
  output: '''
id
kind
first
id
kind
second
id
kind
third
  '''
"""
import deser

type
  FooKind = enum
    First,
    Second,
    Third

  Foo {.ser.} = object
    id: int
    case kind: FooKind
    of First:
      first: string
    of Second:
      second: string
    of Third:
      third: string

var t: Foo

forSer(k, v, t):
  echo k

t = Foo(kind: Second)

forSer(k, v, t):
  echo k

t = Foo(kind: Third)

forSer(k, v, t):
  echo k
