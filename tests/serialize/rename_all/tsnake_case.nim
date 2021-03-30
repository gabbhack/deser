discard """
  output: '''
camel_case
another_camel_case
  '''
"""

import deser

type
  TestToSnakeCase {.ser, renameAll(rkSnakeCase).} = object
    camelCase: int
    anotherCamelCase: int

let tsc = TestToSnakeCase()

forSer key, value, tsc:
  echo key
