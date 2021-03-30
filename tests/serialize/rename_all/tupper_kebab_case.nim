discard """
  output: '''
CAMEL-CASE
ANOTHER-CAMEL-CASE
  '''
"""

import deser

type
  TestToUpperKebabCase {.ser, renameAll(rkUpperKebabCase).} = object
    camelCase: int
    anotherCamelCase: int

let tukc = TestToUpperKebabCase()

forSer key, value, tukc:
  echo key
