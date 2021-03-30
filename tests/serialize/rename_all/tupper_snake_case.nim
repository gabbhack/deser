discard """
  output: '''
CAMEL_CASE
ANOTHER_CAMEL_CASE
  '''
"""

import deser

type
  TestToUpperSnakeCase {.ser, renameAll(rkUpperSnakeCase).} = object
    camelCase: int
    anotherCamelCase: int

let tusc = TestToUpperSnakeCase()

forSer key, value, tusc:
  echo key
