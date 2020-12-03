discard """
  output: '''
snakeCase
anotherSnakeCase
  '''
"""
import macros
import deser

type
  TestToCamelCase {.renameAll(rkCamelCase).} = object
    snake_case: int
    another_snake_case: int

let tcc = TestToCamelCase()

forSerFields key, value, tcc:
  echo key
