discard """
  output: '''
CamelCase
AnotherCamelCase
  '''
"""

import deser

type
  TestToPascalCase {.ser, renameAll(rkPascalCase).} = object
    camelCase: int
    anotherCamelCase: int

let tpc = TestToPascalCase()

forSer key, value, tpc:
  echo key
