discard """
  output: '''
id int 0
kek int 0
lol int 0
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

let f = Foo()

forSerFields key, value, f:
  echo key, " ", value.type, " ", value
