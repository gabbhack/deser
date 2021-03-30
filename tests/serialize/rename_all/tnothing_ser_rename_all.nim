discard """
  output: '''
camelCase
anotherCamelCase
  '''
"""

import deser

type
  TestToKebabCase {.ser, renameAll().} = object
    camelCase: int
    anotherCamelCase: int

let tkc = TestToKebabCase()

forSer key, value, tkc:
  echo key
