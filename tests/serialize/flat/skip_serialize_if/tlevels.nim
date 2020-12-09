discard """
  output: '''
  '''
"""
import macros, options
import deser

proc isInt(x: int): bool = true

type
  Fourth {.skipSerializeIf(isInt).} = object
    fourthOption: Option[int]
    fourth: int
  Third = object
    thirdOption: Option[int]
    fourth {.flat.}: Fourth
  Second = object
    third {.flat.}: Third
  First {.skipSerializeIf(isNone).} = object
    second {.flat.}: Second

let f = First()

forSerFields key, value, f:
  echo key
