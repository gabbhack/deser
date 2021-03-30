discard """
  output: '''
id
kek
lol
  '''
"""

import deser

type
  BarTwo {.ser.} = object
    lol: int

  BarOne {.ser.} = object
    kek: int
    barTwo {.flat.}: BarTwo

  Bar {.ser.} = object
    id: int
    barOne {.flat.}: BarOne

  Foo {.ser.} = object
    bar {.flat.}: Bar

let f = Foo()

forSer key, value, f:
  echo key
