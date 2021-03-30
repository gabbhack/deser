discard """
  output: '''
snakeCase
anotherSnakeCase
  '''
"""

import deser

type
  TestToCamelCase {.des, renameAll(des = rkCamelCase).} = object
    snake_case: int
    another_snake_case: int

var t = TestToCamelCase()

startDes(t):
  forDes(k, v, t):
    echo k
    finish:
      v = some(default(v.get.type))
