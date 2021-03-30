discard """
  output: '''
camel-case
another-camel-case
  '''
"""

import deser

type
  TestToKebabCase {.ser, renameAll(rkKebabCase).} = object
    camelCase: int
    anotherCamelCase: int

let tkc = TestToKebabCase()

forSer key, value, tkc:
  echo key
