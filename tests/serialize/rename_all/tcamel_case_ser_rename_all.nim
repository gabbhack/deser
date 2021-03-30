discard """
  output: '''
snakeCase
anotherSnakeCase
  '''
"""

import deser

type
  TestToCamelCase {.ser, renameAll(rkCamelCase).} = object
    snake_case: int
    another_snake_case: int

let tcc = TestToCamelCase()

forSer key, value, tcc:
  echo key
