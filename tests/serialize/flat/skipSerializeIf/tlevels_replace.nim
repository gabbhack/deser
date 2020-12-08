discard """
  output: '''
fourthOption
  '''
"""
import macros, options
import deser

proc isInt(x: int): bool = true

# `skipSerializeIf` from the Third replaced `skipSerializeIf` from the First
type
  Fourth = object
    fourthOption: Option[int]
    fourth: int
  Third {.skipSerializeIf(isInt).} = object
    thirdOption: Option[int]
    fourth {.flat.}: Fourth
  Second = object
    third {.flat.}: Third
  First {.skipSerializeIf(isNone).} = object
    second {.flat.}: Second

let f = First()

forSerFields key, value, f:
  echo key
