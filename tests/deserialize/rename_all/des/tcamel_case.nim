discard """
  output: '''
snakeCase
anotherSnakeCase
  '''
"""
import macros
import deser

type
  TestToCamelCase {.renameAll(des = rkCamelCase).} = object
    snake_case: int
    another_snake_case: int

var tcc = TestToCamelCase()

forDesFields key, value, tcc:
  echo key
