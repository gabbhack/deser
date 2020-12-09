discard """
  output: '''
id
kek
lol
  '''
"""
import macros
import deser

type
  BarTwo = object
    lol: int

  BarOne = object
    kek: int
    barTwo {.flat.}: BarTwo

  Bar = object
    id: int
    barOne {.flat.}: BarOne
  
  Foo = object
    bar {.flat.}: Bar

var f = Foo()

forDesFields key, value, f:
  echo key
